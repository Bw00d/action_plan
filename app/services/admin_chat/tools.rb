# AdminChat::Tools — tool specifications Claude sees and the Ruby
# dispatchers that execute them. v1 is intentionally narrow: three
# read-only tools (schema inspection + ad-hoc SELECT + a few scoped
# counts), plus one propose_demob tool that returns a *proposal* the
# admin must click to approve. Claude never mutates the DB directly.
module AdminChat
  module Tools
    module_function

    # Only these tables are visible to the chat. Add here as new flows
    # need them — every addition is a privacy / blast-radius decision.
    ALLOWED_TABLES = %w[
      incidents resources rosters checkins demobs schedules
      plans assignments commo_plans phone_205a_entries
      users org_units feature_requests issue_reports
    ].freeze

    MAX_ROWS = 50
    QUERY_TIMEOUT_MS = 5_000

    # ────────────────────────────────────────────────────────────────
    # Schemas — the tools array sent to Claude on every request.
    # ────────────────────────────────────────────────────────────────
    def schemas
      [
        {
          name: 'describe_schema',
          description: <<~DESC.strip,
            List columns and their types for one of the app's tables. Call
            this before run_sql_query if you're not sure what columns exist.
            Returns an array of { name, type, nullable } entries.
          DESC
          input_schema: {
            type: 'object',
            properties: {
              table: { type: 'string', description: "Table name, e.g. 'resources'. Must be one of: #{ALLOWED_TABLES.join(', ')}" }
            },
            required: ['table'],
            additionalProperties: false
          }
        },
        {
          name: 'run_sql_query',
          description: <<~DESC.strip,
            Run a read-only SELECT query against the app's PostgreSQL
            database and return rows as JSON. Rejects anything other than
            SELECT. Capped at #{MAX_ROWS} rows and #{QUERY_TIMEOUT_MS}ms.
            Only tables in the allowlist (see describe_schema's error
            message) are queryable. Use parameterized-looking SQL — single
            quotes around strings, no string concatenation with user input.
          DESC
          input_schema: {
            type: 'object',
            properties: {
              sql: { type: 'string', description: 'A single SELECT statement.' }
            },
            required: ['sql'],
            additionalProperties: false
          }
        },
        {
          name: 'count_resources',
          description: <<~DESC.strip,
            Convenience counter over the Resource table. Returns an
            integer. Resources have no `status` column — their state is
            derived: `active` means release_date IS NULL AND r_and_r = false
            (currently on the incident), `demobed` means release_date is
            set, `on_rnr` means r_and_r = true. `spacer` rows are
            placeholders and are always excluded. `category` is the
            resource type (OVERHEAD, CREW, EQUIPMENT, AIRCRAFT).
          DESC
          input_schema: {
            type: 'object',
            properties: {
              incident_id: { type: 'integer' },
              status:      { type: 'string', enum: %w[active demobed on_rnr all] },
              category:    { type: 'string', enum: %w[OVERHEAD CREW EQUIPMENT AIRCRAFT] },
              checked_in_on: { type: 'string', description: 'YYYY-MM-DD — counts resources that have a Checkin row on that date' }
            },
            additionalProperties: false
          }
        },
        {
          name: 'propose_demob',
          description: <<~DESC.strip,
            Prepare a demob proposal for a single roster entry. DOES NOT
            execute — returns the diff of what would change (release date,
            status flip, incident). The admin reviews and clicks Approve
            in the chat UI to commit it. Use this when a user says things
            like "demob roster 123 for tomorrow" or "release Alice Smith
            from the Pine Fire today".
          DESC
          input_schema: {
            type: 'object',
            properties: {
              roster_id:    { type: 'integer', description: 'The Roster.id to demob.' },
              release_date: { type: 'string',  description: 'YYYY-MM-DD. Defaults to today if omitted.' },
              reason:       { type: 'string',  description: 'Optional free-text note shown to the admin.' }
            },
            required: ['roster_id'],
            additionalProperties: false
          }
        },
        {
          name: 'propose_bulk_transmit_notifications',
          description: <<~DESC.strip,
            Prepare a bulk "mark pending demob notifications as transmitted"
            proposal. DOES NOT execute — returns a count of pending
            notifications that would flip, scoped to the given incident
            and (optionally) a resource category (AIRCRAFT / CREW /
            EQUIPMENT / OVERHEAD). The admin reviews and clicks Approve
            to commit. Use when the user says things like "mark all
            crew demob notifications as transmitted on the Pine Fire".
          DESC
          input_schema: {
            type: 'object',
            properties: {
              incident_id: { type: 'integer', description: 'The Incident.id to scope to.' },
              category:    { type: 'string',  enum: %w[AIRCRAFT CREW EQUIPMENT OVERHEAD],
                             description: 'Optional. Limit to this one dispatcher-facing bucket.' }
            },
            required: ['incident_id'],
            additionalProperties: false
          }
        }
      ]
    end

    # ────────────────────────────────────────────────────────────────
    # Dispatch — called by ClaudeService once per tool_use block.
    # Returns a Hash (will be JSON-serialized into the tool_result).
    # ────────────────────────────────────────────────────────────────
    def dispatch(name, input, user:)
      case name
      when 'describe_schema'  then describe_schema(input['table'])
      when 'run_sql_query'    then run_sql_query(input['sql'])
      when 'count_resources'  then count_resources(input)
      when 'propose_demob'    then propose_demob(input, user: user)
      when 'propose_bulk_transmit_notifications'
        propose_bulk_transmit_notifications(input, user: user)
      else                         { error: "unknown tool: #{name}" }
      end
    rescue StandardError => e
      { error: "#{e.class}: #{e.message}" }
    end

    # ── describe_schema ────────────────────────────────────────────
    def describe_schema(table)
      unless ALLOWED_TABLES.include?(table)
        return { error: "table not allowed. Pick one of: #{ALLOWED_TABLES.join(', ')}" }
      end
      cols = ActiveRecord::Base.connection.columns(table)
      { table: table, columns: cols.map { |c| { name: c.name, type: c.sql_type, nullable: c.null } } }
    end

    # ── run_sql_query ──────────────────────────────────────────────
    def run_sql_query(sql)
      sql = sql.to_s.strip.chomp(';')
      unless sql.match?(/\A\s*(SELECT|WITH)\b/i)
        return { error: 'only SELECT (or WITH … SELECT) statements are allowed' }
      end
      if sql.match?(/\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|GRANT|REVOKE|CREATE|COPY)\b/i)
        return { error: 'write-shaped keyword detected; this tool is read-only' }
      end
      touched = ALLOWED_TABLES.select { |t| sql =~ /\b#{Regexp.escape(t)}\b/i }
      if touched.empty?
        return { error: "no allowed table referenced; allowed: #{ALLOWED_TABLES.join(', ')}" }
      end

      # Wrap in a transaction so the per-statement timeout is scoped to
      # this query, then roll back (nothing to commit on SELECT anyway).
      rows = []
      ActiveRecord::Base.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{QUERY_TIMEOUT_MS}")
        result = ActiveRecord::Base.connection.exec_query("SELECT * FROM (#{sql}) AS _wrapped LIMIT #{MAX_ROWS}")
        rows = result.to_a
        raise ActiveRecord::Rollback
      end
      { row_count: rows.length, rows: rows, truncated: rows.length == MAX_ROWS }
    end

    # ── count_resources ────────────────────────────────────────────
    # Uses the real Resource model's scopes (:active, :overhead, :crew,
    # etc.). Always excludes spacer rows.
    def count_resources(input)
      scope = Resource.where(spacer: false)
      scope = scope.where(incident_id: input['incident_id']) if input['incident_id']
      scope = scope.where(category:    input['category'])    if input['category']
      case input['status']
      when 'active'  then scope = scope.where(release_date: nil, r_and_r: false)
      when 'demobed' then scope = scope.where.not(release_date: nil)
      when 'on_rnr'  then scope = scope.where(r_and_r: true)
      end
      if (iso = input['checked_in_on'])
        date = Date.parse(iso)
        scope = scope.joins(:checkins)
                     .where(checkins: { created_at: date.beginning_of_day..date.end_of_day })
                     .distinct
      end
      { count: scope.count, filters_applied: input.compact }
    end

    # ── propose_demob ──────────────────────────────────────────────
    # Returns a proposal hash. The controller surfaces this to the UI
    # verbatim; the admin's Approve click POSTs to the approvals
    # endpoint, which is what actually mutates the DB.
    def propose_demob(input, user:)
      roster = Roster.find_by(id: input['roster_id'])
      return { error: "no roster found with id #{input['roster_id']}" } unless roster

      release_date = (input['release_date'].presence && Date.parse(input['release_date'])) || Date.current
      {
        proposal_type: 'demob',
        roster_id:     roster.id,
        name:          roster.name,
        incident_name: roster.resource&.incident&.name,
        parent_resource: roster.resource&.name,
        current_status: roster.status,
        current_release_date: roster.demob&.date,
        proposed_release_date: release_date.iso8601,
        proposed_status:       'D',
        reason:                input['reason'],
        # Opaque token the approval endpoint re-validates — not trusted
        # alone, but prevents the UI from fabricating arbitrary targets.
        # Wrap in { } so Ruby 3.x treats this as a positional Hash,
        # not kwargs — message_verifier#generate takes `(value, opts)`.
        token: Rails.application.message_verifier(:admin_chat_demob)
                    .generate({
                      roster_id:    roster.id,
                      release_date: release_date.iso8601,
                      user_id:      user.id,
                      exp:          1.hour.from_now.to_i
                    })
      }
    end

    # ── propose_bulk_transmit_notifications ────────────────────────
    # Returns a proposal that, when approved, marks every pending
    # demob notification on the given incident (optionally scoped to
    # one resource category) as transmitted.
    def propose_bulk_transmit_notifications(input, user:)
      incident = Incident.find_by(id: input['incident_id'])
      return { error: "no incident found with id #{input['incident_id']}" } unless incident
      cat = input['category'].to_s.upcase.presence
      if cat && !%w[AIRCRAFT CREW EQUIPMENT OVERHEAD].include?(cat)
        return { error: "category must be one of AIRCRAFT, CREW, EQUIPMENT, OVERHEAD (got #{input['category'].inspect})" }
      end

      pending = incident.demob_notifications.pending.includes(:resource).to_a
      pending = pending.select { |n| (n.resource&.category.to_s.upcase.presence || 'OTHER') == cat } if cat

      {
        proposal_type:   'bulk_transmit_notifications',
        incident_id:     incident.id,
        incident_name:   incident.name,
        category:        cat,                 # nil means "all categories"
        pending_count:   pending.size,
        sample_names:    pending.first(5).map(&:name),
        token: Rails.application.message_verifier(:admin_chat_bulk_transmit)
                    .generate({
                      incident_id: incident.id,
                      category:    cat,
                      user_id:     user.id,
                      exp:         1.hour.from_now.to_i
                    })
      }
    end
  end
end
