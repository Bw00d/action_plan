module Admin
  class ChatController < ApplicationController
    include SkipAuthorization   # Pundit after_action verify_authorized check — we gate on require_admin instead
    # Needed for #create to stream Server-Sent Events via
    # response.stream.write. Must be included BEFORE before_actions
    # that use the full response (none here, so order is moot).
    include ActionController::Live
    before_action :authenticate_user!
    before_action :require_admin
    # best_in_place / normal admin forms already use CSRF; our AJAX
    # posts send the Rails CSRF token header, so skip_forgery_protection
    # is NOT needed.

    # Session cookie is only ~4KB total — way too small for a chat
    # transcript with tool-use blocks. Store a short UUID in the cookie
    # and keep the actual message array in Rails.cache under that id.
    # Expires after 2 hours of inactivity.
    SESSION_CHAT_ID_KEY = :admin_chat_id
    HISTORY_TTL         = 2.hours

    # GET /admin/chat
    def show
      # Seed the session chat_id up front so the streaming #create
      # action never has to mutate the session (ActionController::Live
      # + session writes can race).
      session[SESSION_CHAT_ID_KEY] ||= SecureRandom.uuid
      @messages = load_history
    end

    # POST /admin/chat/messages — streams the agent loop over
    # Server-Sent Events. Each event is one JSON object on its own
    # `data: ...` line, terminated with a blank line.
    #
    # Event protocol (matches AdminChat::ClaudeService#stream):
    #   {type: "text_delta",  chunk: "..."}       # append to current bubble
    #   {type: "tool_start",  name, input_summary}
    #   {type: "tool_result", name, ok}
    #   {type: "proposal",    payload}            # yellow approval card
    #   {type: "done"}
    #   {type: "error",       message}
    def create
      user_text = params.require(:message).to_s.strip
      if user_text.blank?
        return render json: { error: 'empty message' }, status: :unprocessable_entity
      end

      # rack-timeout defaults to 15s; a chat with 2-3 tool calls can
      # easily run past that. Streaming makes time-to-first-byte tiny
      # anyway, so the usual DoS concern doesn't apply here.
      Rack::Timeout.cancel_timer(request.env) if defined?(Rack::Timeout) && Rack::Timeout.respond_to?(:cancel_timer)

      response.headers['Content-Type']      = 'text/event-stream'
      response.headers['Cache-Control']     = 'no-cache'
      response.headers['X-Accel-Buffering'] = 'no'   # disable nginx buffering
      response.headers.delete('Content-Length')
      # Setting Last-Modified prevents Rack::ETag from needing to buffer
      # the whole body to compute an etag. Without this, middleware
      # pulls the entire stream before sending anything downstream.
      response.headers['Last-Modified'] = Time.now.httpdate

      # Prime the stream: an SSE "comment" (`:` prefix) forces the
      # response head to flush so the browser opens its EventSource
      # buffer immediately, instead of waiting for the first real event.
      response.stream.write(":ok\n\n")

      history = load_history.map(&:deep_symbolize_keys)
      service = AdminChat::ClaudeService.new(user: current_user)

      begin
        final_messages = service.stream(messages: history, user_text: user_text) do |event|
          sse_write(event)
        end
        save_history(trim_history(final_messages))
      rescue Anthropic::Errors::AuthenticationError => e
        Rails.logger.error("Admin chat auth error: #{e.message}")
        sse_write(type: 'error', message: "Anthropic auth failed — check ANTHROPIC_API_KEY. (#{e.message})")
      rescue Anthropic::Errors::RateLimitError
        sse_write(type: 'error', message: 'Rate-limited by Anthropic. Try again in a few seconds.')
      rescue Anthropic::Errors::APIError => e
        Rails.logger.error("Admin chat Anthropic error: #{e.class}: #{e.message}")
        sse_write(type: 'error', message: "Anthropic API error: #{e.message}")
      rescue IOError, ActionController::Live::ClientDisconnected
        # Normal — browser closed the tab mid-stream. Nothing to do.
      rescue StandardError => e
        Rails.logger.error("Admin chat error: #{e.class}: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
        sse_write(type: 'error', message: "#{e.class}: #{e.message}")
      ensure
        response.stream.close
      end
    end

    # DELETE /admin/chat — clear the conversation history (New chat button).
    def destroy
      if (id = session[SESSION_CHAT_ID_KEY])
        Rails.cache.delete(cache_key(id))
      end
      session.delete(SESSION_CHAT_ID_KEY)
      redirect_to admin_chat_path
    end

    # POST /admin/chat/approvals — admin clicks Approve on a proposal
    # the UI received from the chat response. We re-verify the token
    # (signed by propose_demob), then execute the actual mutation.
    def approve
      kind  = params.require(:kind)
      token = params.require(:token)
      case kind
      when 'demob' then approve_demob(token)
      else render json: { error: "unknown proposal kind: #{kind}" }, status: :unprocessable_entity
      end
    end

    private

    def require_admin
      head :forbidden unless current_user&.admin?
    end

    def approve_demob(token)
      payload = Rails.application.message_verifier(:admin_chat_demob).verify(token)
      if payload[:exp].to_i < Time.current.to_i
        return render json: { error: 'proposal token expired — ask the chat to re-propose' },
                      status: :unprocessable_entity
      end

      roster = Roster.find(payload[:roster_id])
      demob  = roster.demob || roster.create_demob!
      demob.update!(date: Date.parse(payload[:release_date]))

      render json: {
        ok: true,
        summary: "Demobed #{roster.name} on #{payload[:release_date]}."
      }
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      render json: { error: 'invalid proposal token' }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'roster no longer exists' }, status: :not_found
    rescue StandardError => e
      Rails.logger.error("Admin chat demob approval failed: #{e.class}: #{e.message}")
      render json: { error: "approval failed: #{e.message}" }, status: :unprocessable_entity
    end

    # Keep the last ~40 messages. Cache-backed so this isn't bounded by
    # cookie size; it just caps per-request token spend to Claude.
    def trim_history(messages)
      messages.last(40)
    end

    def load_history
      id = session[SESSION_CHAT_ID_KEY]
      return [] unless id
      Rails.cache.read(cache_key(id)) || []
    end

    def save_history(messages)
      id = session[SESSION_CHAT_ID_KEY] ||= SecureRandom.uuid
      Rails.cache.write(cache_key(id), messages, expires_in: HISTORY_TTL)
    end

    def cache_key(id)
      "admin_chat:#{id}"
    end

    # Write one Server-Sent Event: a `data: <json>` line followed by a
    # blank line. SSE spec requires the final blank line as a frame
    # delimiter; without it the browser buffers forever.
    def sse_write(event)
      response.stream.write("data: #{event.to_json}\n\n")
    end
  end
end
