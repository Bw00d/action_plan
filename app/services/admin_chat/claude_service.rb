# AdminChat::ClaudeService
# (the anthropic gem is required in config/application.rb; see note there) — drives the agentic tool-use loop against
# Claude Sonnet 5.5. Stateless per request: the caller passes in the
# full conversation history and we return the updated history + a
# user-facing text + any pending proposals the UI must surface.
module AdminChat
  class ClaudeService
    MODEL = :"claude-sonnet-5-5"
    MAX_ITERATIONS = 8   # hard cap on tool-use round-trips per user turn

    SYSTEM_PROMPT = <<~PROMPT
      You are an admin assistant for a Rails 6 wildland-fire Incident Action
      Plan (IAP) app. The user is an admin of this app and can inspect and
      act on its production data. Help them answer questions and take
      actions on incidents, resources, rosters, demobs, schedules, plans,
      and the ICS forms (202-220) stored here.

      Core rules:
        1. Prefer `count_resources` and `describe_schema` + `run_sql_query`
           for data questions. Call `describe_schema` first if you're not
           sure what columns a table has.
        2. All DB mutations go through `propose_demob` (or future
           `propose_*` tools). You never mutate directly. When you want
           to demob someone, call `propose_demob` with the roster_id —
           the UI will show the admin an Approve button; your job is to
           *produce* the proposal, not to assume it was accepted.
        3. If a user asks for an action you can't propose yet, say so
           plainly rather than guessing.
        4. Keep final text answers short — the admin reads them in a
           chat panel, not a report. Numbers, lists, and short sentences.
    PROMPT

    def initialize(user:)
      @user   = user
      @client = Anthropic::Client.new  # reads ENV['ANTHROPIC_API_KEY']
    end

    # Streaming agent loop. Yields SSE-ready events as it goes:
    #
    #   { type: 'text_delta',  chunk: '...' }    # append to current bubble
    #   { type: 'tool_start',  name: '...', input_summary: '...' }
    #   { type: 'tool_result', name: '...', ok: true|false }
    #   { type: 'proposal',    payload: {...} }  # yellow approval card
    #   { type: 'done' }                          # whole turn finished
    #   { type: 'error',       message: '...' }  # fatal, caller should close
    #
    # Returns the final updated messages array (so the controller can
    # persist it). Does NOT catch exceptions — the caller is responsible
    # for emitting an :error event and closing the SSE stream.
    def stream(messages:, user_text:, &on_event)
      messages = messages.dup
      messages << { role: 'user', content: user_text }

      MAX_ITERATIONS.times do |iteration|
        api_stream = @client.messages.stream(
          model:      MODEL,
          max_tokens: 4096,
          system:     SYSTEM_PROMPT,
          tools:      Tools.schemas,
          messages:   messages
        )

        # Stream text deltas as they arrive. The SDK's #text helper
        # exposes only the string chunks; it ignores tool_use blocks,
        # which we handle below from the accumulated message.
        api_stream.text.each do |delta|
          on_event.call(type: 'text_delta', chunk: delta)
        end

        final = api_stream.accumulated_message
        assistant_blocks = final.content.map { |b| block_to_hash(b) }
        messages << { role: 'assistant', content: assistant_blocks }

        break unless final.stop_reason == :tool_use

        # Execute each tool_use block, stream progress to the client,
        # then append the tool_result blocks for the next loop pass.
        tool_results = []
        final.content.each do |block|
          next unless block.type == :tool_use
          input  = block.input.respond_to?(:to_h) ? block.input.to_h.deep_stringify_keys : block.input
          on_event.call(type: 'tool_start', name: block.name,
                        input_summary: summarize_tool_input(block.name, input))

          result = Tools.dispatch(block.name, input, user: @user)

          on_event.call(type: 'tool_result', name: block.name,
                        ok: !result[:error])
          if block.name == 'propose_demob' && !result[:error]
            on_event.call(type: 'proposal', payload: result)
          end
          tool_results << { type: 'tool_result', tool_use_id: block.id,
                            content: result.to_json }
        end
        messages << { role: 'user', content: tool_results }
      end

      on_event.call(type: 'done')
      messages
    end

    private

    def summarize_tool_input(name, input)
      case name
      when 'run_sql_query'   then input['sql'].to_s[0, 80]
      when 'describe_schema' then input['table']
      when 'propose_demob'   then "roster #{input['roster_id']}"
      else                        input.compact.to_json[0, 80]
      end
    end

    public

    # messages: Array<Hash> conversation history (SDK-shape blocks).
    # user_text: the new user turn (plain string).
    # Returns { text:, proposals:, messages: }.
    def respond(messages:, user_text:)
      messages = messages.dup
      messages << { role: 'user', content: user_text }
      proposals = []

      MAX_ITERATIONS.times do
        response = @client.messages.create(
          model: MODEL,
          max_tokens: 4096,
          system: SYSTEM_PROMPT,
          tools: Tools.schemas,
          messages: messages
        )

        # Persist the assistant turn as plain hashes so it round-trips
        # through session storage without SDK objects.
        assistant_blocks = response.content.map { |b| block_to_hash(b) }
        messages << { role: 'assistant', content: assistant_blocks }

        break unless response.stop_reason == :tool_use

        tool_results = []
        response.content.each do |block|
          next unless block.type == :tool_use
          input  = block.input.respond_to?(:to_h) ? block.input.to_h.deep_stringify_keys : block.input
          result = Tools.dispatch(block.name, input, user: @user)
          proposals << result if block.name == 'propose_demob' && !result[:error]
          tool_results << {
            type:         'tool_result',
            tool_use_id:  block.id,
            content:      result.to_json
          }
        end
        messages << { role: 'user', content: tool_results }
      end

      { text: last_assistant_text(messages), proposals: proposals, messages: messages }
    end

    private

    # Convert SDK content blocks to plain-hash shape the API also accepts
    # on the way back in. Covers the block types we emit this turn: text,
    # thinking (passed through unchanged on same-model replays), tool_use.
    def block_to_hash(block)
      case block.type
      when :text
        { type: 'text', text: block.text }
      when :thinking
        { type: 'thinking', thinking: block.thinking, signature: block.signature }
      when :tool_use
        input = block.input.respond_to?(:to_h) ? block.input.to_h : block.input
        { type: 'tool_use', id: block.id, name: block.name, input: input }
      else
        # Fall back to the SDK's own serializer; good enough for refusal /
        # pause_turn blocks we'd just surface and halt on.
        block.respond_to?(:to_h) ? block.to_h : block.as_json
      end
    end

    def last_assistant_text(messages)
      last = messages.reverse.find { |m| m[:role] == 'assistant' || m['role'] == 'assistant' }
      return '' unless last
      content = last[:content] || last['content']
      return content.to_s if content.is_a?(String)
      Array(content).select { |b| (b[:type] || b['type']).to_s == 'text' }
                    .map    { |b| b[:text] || b['text'] }
                    .join("\n\n")
    end
  end
end
