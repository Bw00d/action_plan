# Shift Refactor — Dry Run
#
# Reads every non-spacer Resource plus its ResourceEvent history and prints
# the sequence of :work and :rnr shift entries the real backfill WOULD
# create. Writes nothing to the database.
#
# Run:
#   bin/rails runner script/shift_refactor_dry_run.rb
#
# Flags via ENV:
#   INCIDENT_ID=42 → scope to one incident
#   VERBOSE=1      → print every resource (default: only ones with warnings)
#   ONLY_WARN=1    → print only resources that produced warnings (default)
#   SHOW_TIMELINE=1 → print the full proposed timeline for every printed resource

# frozen_string_literal: true

VERBOSE       = ENV['VERBOSE'] == '1'
SHOW_TIMELINE = ENV['SHOW_TIMELINE'] == '1' || VERBOSE
INCIDENT_ID   = ENV['INCIDENT_ID']&.to_i
TODAY         = Date.current

scope = Resource.where(spacer: false)
scope = scope.where(incident_id: INCIDENT_ID) if INCIDENT_ID
scope = scope.includes(:resource_events).order(:incident_id, :id)

totals = Hash.new(0)
warnings_by_resource = Hash.new { |h, k| h[k] = [] }

def length_from(fwd, lwd)
  return nil if fwd.blank? || lwd.blank?
  (lwd.to_date - fwd.to_date).to_i + 1
end

def fmt(d)
  d.is_a?(Date) ? d.strftime('%Y-%m-%d') : (d.respond_to?(:to_date) ? d.to_date.strftime('%Y-%m-%d') : d.to_s)
end

scope.find_each do |r|
  totals[:resources] += 1
  warnings = []
  entries  = []

  # Skip resources that were never placed — no fwd on the row AND no
  # completed_swap with an fwd. These are "created but unused" rows;
  # the plan calls for leaving them out of the shift timeline. If one
  # is placed later via the normal flow, it'll get its first entry then.
  has_any_fwd = r.fwd.present? ||
                r.resource_events.where(kind: ResourceEvent.kinds[:completed_swap])
                                 .where.not(fwd: nil).exists?
  unless has_any_fwd
    totals[:skipped_unplaced] += 1
    next
  end

  # ---------------------------------------------------------------
  # 1. Past operators: completed_swap events.
  #
  # swap_now records `fwd: @resource.fwd` on EVERY completed_swap — so
  # the fwd column is really the equipment's original fwd, not the
  # operator's start date. The operator's start date is a chain: the
  # first operator starts on resource.fwd; each subsequent operator
  # starts the day AFTER the previous operator's lwd. We order by lwd
  # ASC (NULLS LAST so dateless rows sort last and get warned about).
  # ---------------------------------------------------------------
  completed = r.resource_events.where(kind: ResourceEvent.kinds[:completed_swap])
                               .order(Arel.sql('lwd ASC NULLS LAST, created_at ASC'))

  chain_start = r.fwd    # first operator starts here
  completed.each do |ev|
    if ev.lwd.blank?
      warnings << "completed_swap ##{ev.id} (#{ev.leader}): no lwd — can't place on timeline"
      next
    end
    if chain_start.blank?
      warnings << "completed_swap ##{ev.id} (#{ev.leader}): no chain_start — resource has no fwd and no prior swap lwd"
      next
    end
    if ev.lwd < chain_start
      warnings << "completed_swap ##{ev.id} (#{ev.leader}): lwd #{fmt(ev.lwd)} is BEFORE chain_start #{fmt(chain_start)} — likely dirty data"
      next
    end
    entries << {
      kind:         :work,
      leader:       ev.leader,
      phone:        ev.phone,
      planned_fwd:  chain_start,
      planned_days: (ev.lwd - chain_start).to_i + 1,
      actual_fwd:   chain_start,
      actual_lwd:   ev.lwd,
      source:       "completed_swap ##{ev.id}"
    }
    chain_start = ev.lwd + 1
  end

  # ---------------------------------------------------------------
  # 2. Current operator: lives on the Resource row.
  #    actual_fwd continues the chain from the completed_swap sequence.
  # ---------------------------------------------------------------
  current_start = chain_start

  if current_start.blank?
    # No fwd anywhere — this resource has never been placed. Skip the
    # current-operator entry; still need to decide what to do with
    # any scheduled_swap/r_and_r below.
    warnings << "resource has no fwd and no completed_swap with fwd — no current :work entry generated"
  else
    planned_end = (r.fwd && r.assignment_length.to_i.positive?) ? (r.fwd + r.assignment_length.to_i - 1) : nil
    actual_lwd  = r.release_date   # nil if still active
    # Guard against release_date pointing to a date BEFORE the current
    # operator's start — happens in dev when swap_now ran after an
    # earlier demob without clearing release_date. Treat as still active
    # and surface it so the admin can clean up.
    if actual_lwd.present? && actual_lwd < current_start
      warnings << "release_date #{fmt(actual_lwd)} is before current operator's start #{fmt(current_start)} — treating as still active"
      actual_lwd = nil
    end
    planned_days =
      if planned_end
        [(planned_end - current_start).to_i + 1, 0].max
      end

    # Solo-individual categories (OVERHEAD, etc.) carry the person's
    # name in resource.name and leave resource.leader blank — the
    # resource IS the leader. Fall back to the name so per-leader day
    # totals and feed display work uniformly.
    effective_leader = r.leader.presence || r.name
    entries << {
      kind:         :work,
      leader:       effective_leader,
      phone:        r.phone,
      planned_fwd:  current_start,
      planned_days: planned_days,
      actual_fwd:   current_start,
      actual_lwd:   actual_lwd,
      source:       'resource row (current operator)'
    }

    warnings << "current operator has no leader and no name" if effective_leader.blank? && actual_lwd.blank?
  end

  # ---------------------------------------------------------------
  # 3. R&R (currently just a boolean). Plan says: backfill as an
  #    :rnr entry starting today. Duration unknown — we insert with
  #    planned_days = nil and flag it for the admin to resolve.
  # ---------------------------------------------------------------
  if r.r_and_r
    if r.release_date.present?
      warnings << "r_and_r=true AND release_date=#{r.release_date} — ambiguous: already demobbed?"
    end
    # No start date or duration is stored today, so backfill with a
    # 2-day default starting today. Admin can adjust per card.
    entries << {
      kind:         :rnr,
      leader:       r.leader.presence || r.name,  # inherited for display
      phone:        nil,
      planned_fwd:  TODAY,
      planned_days: 2,
      actual_fwd:   TODAY,
      actual_lwd:   nil,
      source:       'resource.r_and_r=true (default 2-day duration)'
    }
    warnings << 'r_and_r backfilled with default 2 days — admin should confirm'
  end

  # ---------------------------------------------------------------
  # 4. Future operators: scheduled_swap events.
  # ---------------------------------------------------------------
  scheduled = r.resource_events.where(kind: ResourceEvent.kinds[:scheduled_swap])
                               .order(Arel.sql('fwd ASC NULLS LAST'))

  scheduled.each do |ev|
    if ev.fwd.blank?
      warnings << "scheduled_swap ##{ev.id} (#{ev.leader}): no fwd — can't place on timeline"
      next
    end
    entries << {
      kind:         :work,
      leader:       ev.leader,
      phone:        ev.phone,
      planned_fwd:  ev.fwd,
      planned_days: length_from(ev.fwd, ev.lwd),  # may be nil
      actual_fwd:   nil,
      actual_lwd:   nil,
      source:       "scheduled_swap ##{ev.id}"
    }
  end

  # ---------------------------------------------------------------
  # 5. Timeline validation: no overlaps, chronological order.
  # ---------------------------------------------------------------
  placed = entries.select { |e| e[:planned_fwd].present? }
                  .sort_by { |e| e[:planned_fwd] }

  placed.each_cons(2) do |a, b|
    a_end = a[:actual_lwd] ||
            (a[:planned_fwd] && a[:planned_days] ? a[:planned_fwd] + a[:planned_days] - 1 : nil)
    next if a_end.blank?
    if a_end >= b[:planned_fwd]
      warnings << "overlap: #{a[:source]} ends #{fmt(a_end)}, " \
                  "#{b[:source]} starts #{fmt(b[:planned_fwd])} " \
                  "(effective end rule will truncate the earlier one)"
    end
  end

  # ---------------------------------------------------------------
  # Totals + warnings bookkeeping
  # ---------------------------------------------------------------
  totals[:work_entries] += entries.count { |e| e[:kind] == :work }
  totals[:rnr_entries]  += entries.count { |e| e[:kind] == :rnr }
  totals[:with_warnings] += 1 if warnings.any?
  warnings_by_resource[r.id] = warnings if warnings.any?

  # ---------------------------------------------------------------
  # Print this resource if interesting
  # ---------------------------------------------------------------
  should_print = VERBOSE || warnings.any?
  if should_print
    puts "---"
    puts "Resource ##{r.id} #{r.name.inspect} (#{r.category}) incident=#{r.incident_id}  " \
         "fwd=#{fmt(r.fwd)}  len=#{r.assignment_length}  release=#{fmt(r.release_date)}  r_and_r=#{r.r_and_r}"
    if SHOW_TIMELINE || warnings.any?
      entries.each do |e|
        line = "  [#{e[:kind]}]  "
        line += "#{e[:leader].to_s.ljust(20)} "
        line += "planned #{fmt(e[:planned_fwd])}"
        line += " for #{e[:planned_days]}d" if e[:planned_days]
        line += "  actual #{fmt(e[:actual_fwd])}→#{fmt(e[:actual_lwd])}" if e[:actual_fwd] || e[:actual_lwd]
        line += "  (#{e[:source]})"
        puts line
      end
    end
    warnings.each { |w| puts "  WARN: #{w}" }
  end
end

puts
puts "============================================================"
puts " SHIFT REFACTOR DRY RUN — SUMMARY"
puts "============================================================"
puts "  Resources inspected      : #{totals[:resources]}"
puts "  Skipped (never placed)   : #{totals[:skipped_unplaced]}"
puts "  :work entries planned    : #{totals[:work_entries]}"
puts "  :rnr entries planned     : #{totals[:rnr_entries]}"
puts "  Resources with warnings  : #{totals[:with_warnings]}"
puts
if warnings_by_resource.any? && !VERBOSE
  puts " Rerun with VERBOSE=1 or SHOW_TIMELINE=1 to see every resource's timeline."
  puts " Only resources with warnings were printed above."
end
puts "============================================================"
