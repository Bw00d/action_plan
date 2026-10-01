# Parses an e-iSuite "Resources" CSV export and either upserts Resource +
# Roster rows into the given incident directly, or produces a diff Plan so
# the operator can preview and pick which existing rows to update.
#
# CSV shape (as of 2026):
#   Request #, Resource Name, Item Code, Status, Agency, Item Name,
#   Unit ID, Check-In Date, First Work Day, Length of Assignment,
#   # Personnel
#
# Request # encodes hierarchy: "A-1" is a parent Resource; "A-1.3" is a
# roster entry under it. Categories come from the leading letter (A/C/E/O).
# "S" rows are services — skipped.
#
# Status: C = active, R = R&R, D = demobed (skipped).
require "csv"

class IsuiteImporter
  CATEGORY_FROM_PREFIX = {
    "A" => "AIRCRAFT",
    "C" => "CREW",
    "E" => "EQUIPMENT",
    "O" => "OVERHEAD"
  }.freeze

  # Fields on Resource that we compare + update from the CSV. Kept small
  # on purpose — CSV columns that are optional (personnel, length) are
  # only diffed when the CSV actually provided a value.
  RESOURCE_DIFF_FIELDS = %i[
    name position agency number_personnel assignment_length
    checkin_date fwd r_and_r
  ].freeze

  ROSTER_DIFF_FIELDS = %i[name position agency released].freeze

  Result = Struct.new(
    :resources_created, :resources_skipped, :resources_updated,
    :rosters_created,   :rosters_skipped,   :rosters_updated,
    :resources_demobed, :rosters_demobed,
    :demobed_skipped,   :filled_skipped,    :service_skipped,
    :errors,
    keyword_init: true
  )

  # Preview plan built from the CSV. Everything is plain data (no AR
  # objects) so it round-trips through Rails.cache cleanly.
  Plan = Struct.new(
    :new_resources, :new_rosters,
    :resource_changes, :roster_changes,
    :unchanged_count, :demobed_skipped, :filled_skipped, :service_skipped, :errors,
    keyword_init: true
  )

  # `io` — anything CSV.new can read.
  def initialize(io)
    @io = io
  end

  # Preview: parses CSV and returns a Plan comparing to the incident's
  # current state.
  def plan_for(incident)
    rows = parse_rows
    build_plan(incident, rows)
  end

  # One-shot import (used when there's nothing to preview or the caller
  # explicitly wants create-only behavior). Equivalent to the original
  # behavior: skip existing, don't touch anything already in the DB.
  def import_into(incident)
    plan = plan_for(incident)
    apply_plan(incident, plan,
               resource_ids: plan.resource_changes.map { |c| c[:resource_id] }.to_set,
               roster_ids:   plan.roster_changes.map { |c| c[:roster_id] }.to_set,
               skip_updates: true)
  end

  # Apply a previously-computed plan against the incident.
  # selected_resource_ids / selected_roster_ids: arrays of AR ids the user
  # ticked in the preview. New resources / rosters are always created; only
  # updates are gated.
  def self.apply(incident, rows, selected_resource_ids:, selected_roster_ids:)
    importer = new(nil)
    plan     = importer.send(:build_plan, incident, rows)
    importer.send(:apply_plan, incident, plan,
                  resource_ids: selected_resource_ids.map(&:to_i).to_set,
                  roster_ids:   selected_roster_ids.map(&:to_i).to_set,
                  skip_updates: false)
  end

  # Exposed so the controller can cache parsed rows for the preview →
  # apply round-trip.
  def parsed_rows
    parse_rows
  end

  private

  def build_plan(incident, rows)
    parents, children = rows.partition { |r| r[:child_num].nil? }
    resource_by_key   = incident.resources.each_with_object({}) do |r, h|
      h["#{r.category}-#{r.order_number}"] = r
    end

    plan = Plan.new(
      new_resources: [], new_rosters: [],
      resource_changes: [], roster_changes: [],
      unchanged_count: 0,
      demobed_skipped: 0, filled_skipped: 0, service_skipped: 0,
      errors: []
    )

    # Status handling:
    #   C = Checked in     → import as active
    #   R = On R&R         → import with r_and_r: true
    #   F = Filled (iSuite requisition filled elsewhere) → ignore entirely
    #   D = Demobed →
    #     • not in our DB OR already released here → ignore
    #     • in our DB and still active → surface as a "DEMOB" change the
    #       user can accept in the preview; apply sets release_date and
    #       cascades through the normal demob flow (DemobNotification +
    #       remove_from_board).
    parents.each do |row|
      if row[:category].nil? then plan.service_skipped += 1; next; end
      # F = Filled requisition (filled from elsewhere) → ignore. Other
      # statuses pass through: C/R/P are all currently checked in
      # (P = pending demob, usually within 48h, treated same as C), and
      # D gets its own branch below.
      if row[:status] == "F" then plan.filled_skipped += 1; next; end

      existing = resource_by_key["#{row[:category]}-#{row[:parent_num]}"]

      if row[:status] == "D"
        if existing.nil? || existing.release_date.present?
          plan.demobed_skipped += 1
        else
          # Active in our DB but iSuite marks demobed → propose a demob.
          # Prefer the CSV's Actual Release Date when provided; fall
          # back to today for older exports that omit it.
          release_date = row[:actual_release_date] || Date.current
          plan.resource_changes << {
            resource_id:  existing.id,
            request:      row[:request],
            name:         existing.name,
            position:     existing.position,
            diffs:        { release_date: [existing.release_date, release_date] },
            demob:        true,
            release_time: row[:actual_release_time].presence
          }
        end
        next
      end

      if existing.nil?
        plan.new_resources << row
      else
        diffs = resource_diffs(existing, row, children)
        if diffs.empty?
          plan.unchanged_count += 1
        else
          plan.resource_changes << {
            resource_id: existing.id,
            request:     row[:request],
            name:        existing.name,
            position:    existing.position,
            diffs:       diffs
          }
        end
      end
    end

    children.each do |row|
      if row[:category].nil? then plan.service_skipped += 1; next; end
      # F = Filled requisition (filled from elsewhere) → ignore. Other
      # statuses pass through: C/R/P are all currently checked in
      # (P = pending demob, usually within 48h, treated same as C), and
      # D gets its own branch below.
      if row[:status] == "F" then plan.filled_skipped += 1; next; end

      parent          = resource_by_key["#{row[:category]}-#{row[:parent_num]}"]
      existing_roster = parent&.rosters&.find_by(order_number: row[:child_num])

      if row[:status] == "D"
        if existing_roster.nil? || existing_roster.released_at.present?
          plan.demobed_skipped += 1
        else
          plan.roster_changes << {
            roster_id:   existing_roster.id,
            request:     row[:request],
            name:        existing_roster.name,
            position:    existing_roster.position,
            diffs:       { released: [false, true] },
            demob:       true
          }
        end
        next
      end

      unless parent
        # Parent will be created this run — treat as new roster to add.
        plan.new_rosters << row
        next
      end

      if existing_roster.nil?
        plan.new_rosters << row
      else
        diffs = roster_diffs(existing_roster, row)
        if diffs.empty?
          plan.unchanged_count += 1
        else
          plan.roster_changes << {
            roster_id:   existing_roster.id,
            request:     row[:request],
            name:        existing_roster.name,
            position:    existing_roster.position,
            diffs:       diffs
          }
        end
      end
    end

    plan
  end

  # Returns a hash of { field_symbol => [old_value, new_value] } for every
  # field that would change on this Resource if the CSV row were applied.
  def resource_diffs(resource, row, all_children)
    incoming = incoming_resource_attrs(row, all_children)
    incoming.each_with_object({}) do |(field, new_val), diffs|
      old_val = resource.public_send(field)
      # Normalize dates so a Date == a Date, and skip when CSV blanks a
      # field we already have populated (don't wipe DB values with nil).
      next if new_val.nil?
      next if values_equal?(old_val, new_val)
      diffs[field] = [old_val, new_val]
    end
  end

  def roster_diffs(roster, row)
    incoming = {
      name:     row[:name].presence,
      position: row[:item_code].presence,
      agency:   row[:agency].presence,
      released: row[:status] == "R"
    }
    incoming.each_with_object({}) do |(field, new_val), diffs|
      # `released` is a boolean derived from status; only diff when the
      # released_at column actually flips (nil ↔ set).
      if field == :released
        currently = roster.released_at.present?
        diffs[:released] = [currently, new_val] if currently != new_val
        next
      end
      next if new_val.nil?
      old_val = roster.public_send(field)
      next if values_equal?(old_val, new_val)
      diffs[field] = [old_val, new_val]
    end
  end

  def incoming_resource_attrs(row, all_children)
    child_count = all_children.count do |c|
      c[:parent_num] == row[:parent_num] && c[:prefix] == row[:prefix] && c[:status] != "D"
    end
    personnel = row[:personnel].to_i.positive? ? row[:personnel].to_i : nil
    length    = row[:assignment_length].to_i.positive? ? row[:assignment_length].to_i : nil

    {
      name:              row[:name].presence,
      position:          row[:item_code].presence,
      agency:            row[:agency].presence,
      number_personnel:  personnel,
      assignment_length: length,
      checkin_date:      row[:checkin_date],
      fwd:               row[:fwd],
      r_and_r:           row[:status] == "R",
      # Newer-export fields — only diff when the CSV actually provided
      # a non-blank value so sparse exports don't wipe existing data.
      leader:            row[:leader_name].presence,
      phone:             row[:cell_phone].presence,
      return_city:       row[:demob_city].presence
    }
  end

  def values_equal?(a, b)
    return true if a == b
    if a.is_a?(Date) && b.is_a?(Date)
      a == b
    elsif a.is_a?(String) && b.is_a?(String)
      a.strip == b.strip
    else
      a.to_s == b.to_s
    end
  end

  def apply_plan(incident, plan, resource_ids:, roster_ids:, skip_updates:)
    result = Result.new(
      resources_created: 0, resources_skipped: 0, resources_updated: 0,
      rosters_created:   0, rosters_skipped:   0, rosters_updated:   0,
      resources_demobed: 0, rosters_demobed:   0,
      demobed_skipped:   plan.demobed_skipped,
      filled_skipped:    plan.filled_skipped,
      service_skipped:   plan.service_skipped,
      errors:            plan.errors.dup
    )

    # -- Create new parent resources --
    resource_by_key = incident.resources.each_with_object({}) do |r, h|
      h["#{r.category}-#{r.order_number}"] = r
    end

    plan.new_resources.each do |row|
      key = "#{row[:category]}-#{row[:parent_num]}"
      if resource_by_key.key?(key)
        result.resources_skipped += 1
        next
      end
      child_count = plan.new_rosters.count do |c|
        c[:parent_num] == row[:parent_num] && c[:prefix] == row[:prefix]
      end
      personnel = row[:personnel].to_i.positive? ? row[:personnel].to_i : [child_count, 1].max
      length    = row[:assignment_length].to_i.positive? ? row[:assignment_length].to_i : 14

      resource = incident.resources.build(
        category:          row[:category],
        order_number:      row[:parent_num],
        name:              row[:name],
        position:          row[:item_code],
        agency:            row[:agency].presence || "—",
        number_personnel:  personnel,
        assignment_length: length,
        checkin_date:      row[:checkin_date],
        fwd:               row[:fwd],
        r_and_r:           row[:status] == "R",
        leader:            row[:leader_name].presence,
        phone:             row[:cell_phone].presence,
        return_city:       row[:demob_city].presence
      )
      if resource.save
        resource_by_key[key] = resource
        result.resources_created += 1
      else
        result.errors << "#{row[:request]}: #{resource.errors.full_messages.join('; ')}"
      end
    end

    # -- Apply selected updates to existing resources --
    unless skip_updates
      plan.resource_changes.each do |change|
        next unless resource_ids.include?(change[:resource_id])
        resource = incident.resources.find_by(id: change[:resource_id])
        next unless resource

        if change[:demob]
          # Route through the Demob record so the normal release flow
          # fires: Demob#release_resource sets resource.release_date,
          # resource.remove_from_board_on_demob destroys the OrgUnit
          # assignment, and DemobNotification.from_demob is created.
          demob = resource.demob || Demob.create!(resource_id: resource.id)
          attrs = { actual_release_date: change[:diffs][:release_date].last }
          attrs[:actual_release_time] = change[:release_time] if change[:release_time]
          if demob.update(attrs)
            result.resources_demobed += 1
          else
            result.errors << "#{change[:request]}: #{demob.errors.full_messages.join('; ')}"
          end
        else
          attrs = change[:diffs].transform_values(&:last)
          if resource.update(attrs)
            result.resources_updated += 1
          else
            result.errors << "#{change[:request]}: #{resource.errors.full_messages.join('; ')}"
          end
        end
      end
    end

    # -- Create new roster entries --
    plan.new_rosters.each do |row|
      parent = resource_by_key["#{row[:category]}-#{row[:parent_num]}"]
      unless parent
        result.errors << "#{row[:request]}: parent #{row[:prefix]}-#{row[:parent_num]} not found"
        next
      end
      if parent.rosters.exists?(order_number: row[:child_num])
        result.rosters_skipped += 1
        next
      end
      roster = parent.rosters.build(
        name:         row[:name],
        position:     row[:item_code],
        order_number: row[:child_num],
        agency:       row[:agency],
        released_at:  (row[:status] == "R" ? Time.current : nil)
      )
      if roster.save
        result.rosters_created += 1
      else
        result.errors << "#{row[:request]}: #{roster.errors.full_messages.join('; ')}"
      end
    end

    # -- Apply selected updates to existing rosters --
    unless skip_updates
      plan.roster_changes.each do |change|
        next unless roster_ids.include?(change[:roster_id])
        roster = Roster.find_by(id: change[:roster_id])
        next unless roster

        if change[:demob]
          if roster.update(released_at: Time.current)
            result.rosters_demobed += 1
          else
            result.errors << "#{change[:request]}: #{roster.errors.full_messages.join('; ')}"
          end
        else
          attrs = change[:diffs].each_with_object({}) do |(field, (_old, new_val)), h|
            if field == :released
              h[:released_at] = new_val ? (roster.released_at || Time.current) : nil
            else
              h[field] = new_val
            end
          end
          if roster.update(attrs)
            result.rosters_updated += 1
          else
            result.errors << "#{change[:request]}: #{roster.errors.full_messages.join('; ')}"
          end
        end
      end
    end

    result
  end

  def parse_rows
    raw = @io.respond_to?(:read) ? @io.read : @io.to_s
    raw = raw.force_encoding("UTF-8")
    raw = raw.sub(/\A\xEF\xBB\xBF/, "")
    CSV.parse(raw, headers: true).each_with_object([]) do |csv_row, out|
      request = csv_row["Request #"].to_s.strip
      next if request.empty?

      prefix, rest = request.split("-", 2)
      next if rest.nil?

      parent_num, child_num = rest.split(".", 2)

      # Any column not present in the particular CSV returns nil via
      # CSV::Row#[], which `.to_s` turns into "" — the import tolerates
      # missing columns automatically and never errors on exports with
      # a smaller schema than this importer knows about. New columns
      # that show up in future exports simply go unused.
      out << {
        request:              request,
        prefix:               prefix,
        parent_num:           parent_num,
        child_num:            child_num,
        category:             CATEGORY_FROM_PREFIX[prefix],
        name:                 csv_row["Resource Name"].to_s.strip,
        item_code:            csv_row["Item Code"].to_s.strip,
        status:               csv_row["Status"].to_s.strip,
        agency:               csv_row["Agency"].to_s.strip,
        item_name:            csv_row["Item Name"].to_s.strip,
        unit_id:              csv_row["Unit ID"].to_s.strip,
        checkin_date:         parse_date(csv_row["Check-In Date"]),
        fwd:                  parse_date(csv_row["First Work Day"]),
        assignment_length:    csv_row["Length of Assignment"].to_s.strip,
        personnel:            csv_row["# Personnel"].to_s.strip,
        # Newer-export columns — safe no-ops when the column is missing.
        actual_release_date:  parse_date(csv_row["Actual Release Date"]),
        actual_release_time:  csv_row["Actual Release Time"].to_s.strip,
        cell_phone:           csv_row["Cell Phone"].to_s.strip,
        demob_city:           csv_row["Demob City"].to_s.strip,
        leader_name:          csv_row["Leader Name"].to_s.strip
      }
    end
  end

  def parse_date(str)
    return nil if str.blank?
    Date.strptime(str.strip, "%m/%d/%Y")
  rescue ArgumentError
    nil
  end
end
