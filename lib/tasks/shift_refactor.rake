# Shift refactor backfill.
#
# Converts a resource's legacy ResourceEvent history (scheduled_swap +
# completed_swap kinds) and `r_and_r` boolean into a :work/:rnr
# timeline. Idempotent — a resource that already has any :work or :rnr
# entries is treated as "already backfilled" and skipped entirely.
#
# Each resource is wrapped in its own transaction: partial failures
# never leave a resource half-converted. If one resource errors, the
# rest keep going; the summary at the end reports failures.
#
# ENV:
#   INCIDENT_ID=42  scope to one incident
#   RESOURCE_ID=99  scope to one resource (useful for spot-checks)
#   VERBOSE=1       print every resource's actions
#   DRY_RUN=1       no DB writes (use `script/shift_refactor_dry_run.rb`
#                   for the richer dry-run; this flag is a last-second
#                   safety belt in case someone runs the real task by
#                   mistake)
#
# Run:
#   bin/rails shift_refactor:backfill
#   DRY_RUN=1 bin/rails shift_refactor:backfill        # paranoid preview
#   INCIDENT_ID=36 bin/rails shift_refactor:backfill   # one incident

namespace :shift_refactor do
  desc 'Backfill legacy ResourceEvent history into :work/:rnr shift timeline'
  task backfill: :environment do
    VERBOSE = ENV['VERBOSE'] == '1'
    DRY_RUN = ENV['DRY_RUN'] == '1'
    TODAY   = Date.current

    scope = Resource.where(spacer: false)
    scope = scope.where(incident_id: ENV['INCIDENT_ID']) if ENV['INCIDENT_ID']
    scope = scope.where(id: ENV['RESOURCE_ID'])          if ENV['RESOURCE_ID']

    totals = Hash.new(0)
    failures = []

    puts "=== Shift refactor backfill (#{DRY_RUN ? 'DRY RUN' : 'LIVE'}) ==="
    puts "Scope: #{scope.count} resources"

    scope.find_each(batch_size: 100) do |r|
      totals[:resources] += 1

      # ---------------------------------------------------------
      # Idempotency: if this resource already has any :work or :rnr
      # entry, assume it was backfilled on an earlier run and skip.
      # ---------------------------------------------------------
      if r.resource_events.where(kind: [ResourceEvent.kinds[:work],
                                        ResourceEvent.kinds[:rnr]]).exists?
        totals[:skipped_already_backfilled] += 1
        puts "  skip ##{r.id} #{r.name.inspect} — already has :work/:rnr entries" if VERBOSE
        next
      end

      # ---------------------------------------------------------
      # Skip resources that were never placed (no fwd anywhere).
      # ---------------------------------------------------------
      has_any_fwd = r.fwd.present? ||
                    r.resource_events.where(kind: ResourceEvent.kinds[:completed_swap])
                                     .where.not(fwd: nil).exists?
      unless has_any_fwd
        totals[:skipped_unplaced] += 1
        # Demote any orphan legacy swap events on this unplaced
        # resource so no :scheduled_swap/:completed_swap rows survive
        # the backfill. Preserves the leader info in the body.
        r.resource_events.where(kind: [ResourceEvent.kinds[:scheduled_swap],
                                       ResourceEvent.kinds[:completed_swap]]).each do |ev|
          note = "[auto] legacy #{ev.kind} on unplaced resource (no fwd). " \
                 "Original leader: #{ev.leader.inspect}, created: #{ev.created_at}."
          ev.update!(kind: :comment,
                     body: [ev.body.to_s.strip, note].reject(&:empty?).join("\n\n"))
          totals[:orphan_demoted_to_comment] += 1
        end
        next
      end

      begin
        ActiveRecord::Base.transaction do
          # -----------------------------------------------------
          # 1. Rewrite completed_swap events into :work entries.
          #
          #    swap_now wrote completed_swap.fwd = resource.fwd for
          #    EVERY swap, so the fwd column is the equipment's
          #    original fwd, not the operator's. Chain the operator's
          #    actual start dates off the lwd sequence.
          # -----------------------------------------------------
          chain_start = r.fwd
          completed = r.resource_events
                       .where(kind: ResourceEvent.kinds[:completed_swap])
                       .order(Arel.sql('lwd ASC NULLS LAST, created_at ASC'))

          completed.each do |ev|
            unplaceable_reason =
              if ev.lwd.blank?
                "no lwd"
              elsif chain_start.blank?
                "no chain start (resource has no fwd)"
              elsif ev.lwd < chain_start
                "lwd #{ev.lwd} precedes chain_start #{chain_start} — likely two swaps on the same day"
              end

            if unplaceable_reason
              # Can't place on the timeline without inventing a shift
              # with actual_fwd > actual_lwd. Demote to a comment so
              # no history is lost, flag it in the body.
              note = "[auto] couldn't place historical swap on shift timeline (#{unplaceable_reason}). " \
                     "Original leader: #{ev.leader.inspect}, created: #{ev.created_at}."
              ev.update!(kind: :comment,
                         body: [ev.body.to_s.strip, note].reject(&:empty?).join("\n\n"))
              totals[:completed_demoted_to_comment] += 1
              next
            end

            ev.update!(kind:       :work,
                       fwd:        chain_start,
                       lwd:        ev.lwd,
                       actual_fwd: chain_start,
                       actual_lwd: ev.lwd)
            totals[:completed_rewritten] += 1
            chain_start = ev.lwd + 1
          end

          # -----------------------------------------------------
          # 2. Create a :work entry for the CURRENT operator from
          #    the Resource row. (The row data stays unchanged;
          #    this is additive.)
          # -----------------------------------------------------
          current_start = chain_start
          planned_end   = (r.fwd && r.assignment_length.to_i.positive?) ?
                          (r.fwd + r.assignment_length.to_i - 1) : nil
          actual_lwd    = r.release_date
          if actual_lwd.present? && actual_lwd < current_start
            actual_lwd = nil   # dirty data — treat as still active
            totals[:current_release_before_start] += 1
          end
          effective_leader = r.leader.presence || r.name

          r.resource_events.create!(
            kind:       :work,
            leader:     effective_leader,
            phone:      r.phone,
            fwd:        current_start,
            lwd:        planned_end,       # may be nil
            actual_fwd: current_start,
            actual_lwd: actual_lwd
          )
          totals[:current_created] += 1

          # -----------------------------------------------------
          # 3. Create an :rnr entry if the resource is on R&R.
          #    Default 2-day duration; admin can adjust.
          # -----------------------------------------------------
          if r.r_and_r
            r.resource_events.create!(
              kind:       :rnr,
              leader:     effective_leader,
              fwd:        TODAY,
              lwd:        TODAY + 1,       # 2-day default
              actual_fwd: TODAY,
              actual_lwd: nil
            )
            totals[:rnr_created] += 1
          end

          # -----------------------------------------------------
          # 4. Rewrite scheduled_swap events into :work entries.
          #    The user-entered fwd/lwd/leader/phone are already
          #    correct for the incoming operator; just flip kind.
          # -----------------------------------------------------
          scheduled = r.resource_events
                       .where(kind: ResourceEvent.kinds[:scheduled_swap])
          scheduled.each do |ev|
            ev.update!(kind: :work)   # fwd/lwd/leader/phone untouched
            totals[:scheduled_rewritten] += 1
          end

          # Dry-run paranoia: roll everything back.
          raise ActiveRecord::Rollback if DRY_RUN
        end

        puts "  ok ##{r.id} #{r.name.inspect}" if VERBOSE
      rescue => e
        failures << { id: r.id, name: r.name, error: "#{e.class}: #{e.message}" }
        puts "  FAIL ##{r.id} #{r.name.inspect} — #{e.class}: #{e.message}"
      end
    end

    puts
    puts "============================================================"
    puts " SHIFT REFACTOR BACKFILL — SUMMARY  (#{DRY_RUN ? 'DRY RUN — rolled back' : 'LIVE'})"
    puts "============================================================"
    puts "  Resources scanned             : #{totals[:resources]}"
    puts "  Skipped (already backfilled)  : #{totals[:skipped_already_backfilled]}"
    puts "  Skipped (never placed)        : #{totals[:skipped_unplaced]}"
    puts "  Orphan swap → :comment        : #{totals[:orphan_demoted_to_comment]}"
    puts "  completed_swap → :work                  : #{totals[:completed_rewritten]}"
    puts "  completed_swap → :comment (unplaceable) : #{totals[:completed_demoted_to_comment]}"
    puts "  Current operator :work rows   : #{totals[:current_created]}"
    puts "  Current w/ release_date<start cleared   : #{totals[:current_release_before_start]}"
    puts "  :rnr rows created             : #{totals[:rnr_created]}"
    puts "  scheduled_swap → :work        : #{totals[:scheduled_rewritten]}"
    puts "  Failures                      : #{failures.size}"
    failures.each { |f| puts "    FAIL ##{f[:id]} #{f[:name].inspect} — #{f[:error]}" }
    puts "============================================================"
    puts
    puts 'Legacy :scheduled_swap / :completed_swap rows remaining in DB (should be 0 after a full live run):'
    puts "  scheduled_swap: #{ResourceEvent.where(kind: :scheduled_swap).count}"
    puts "  completed_swap: #{ResourceEvent.where(kind: :completed_swap).count}"
  end
end
