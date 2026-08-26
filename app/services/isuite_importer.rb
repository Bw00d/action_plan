# Parses an e-iSuite "Resources" CSV export and upserts Resource + Roster
# rows into the given incident. Idempotent — re-running the import doesn't
# create duplicates.
#
# CSV shape (as of 2026):
#   Request #, Resource Name, Item Code, Status, Agency, Item Name,
#   Unit ID, Check-In Date, First Work Day, Length of Assignment,
#   # Personnel
#
# The last three columns are optional — older exports don't include them.
# When present and non-zero we honor the CSV value; otherwise we fall back
# (personnel = count of active child rosters, length = 14, fwd = nil).
#
# Request # encodes the hierarchy: "A-1" is a parent resource; "A-1.3" is
# a roster entry under it. Categories come from the leading letter
# (A=AIRCRAFT, C=CREW, E=EQUIPMENT, O=OVERHEAD). S rows are services (land
# rentals, etc.) — not a Resource category we support today, so we skip
# them and return a count in the summary.
#
# Status codes:
#   C  = Checked in    → import as active
#   R  = On R&R        → import with r_and_r: true
#   D  = Demobed       → skip (already left the incident)
require "csv"

class IsuiteImporter
  CATEGORY_FROM_PREFIX = {
    "A" => "AIRCRAFT",
    "C" => "CREW",
    "E" => "EQUIPMENT",
    "O" => "OVERHEAD"
  }.freeze

  Result = Struct.new(
    :resources_created, :resources_skipped,
    :rosters_created,   :rosters_skipped,
    :demobed_skipped,   :service_skipped,
    :errors,
    keyword_init: true
  )

  # `io` — anything CSV.new can read (File, StringIO, ActionDispatch::Http::UploadedFile#tempfile)
  def initialize(io)
    @io = io
  end

  def import_into(incident)
    rows = parse_rows
    parents, children = rows.partition { |r| r[:child_num].nil? }

    result = Result.new(
      resources_created: 0, resources_skipped: 0,
      rosters_created:   0, rosters_skipped:   0,
      demobed_skipped:   0, service_skipped:   0,
      errors: []
    )

    # Build a lookup of already-existing Resources keyed by "category-order"
    # so both new-parent creation and child-parent resolution can hit it.
    existing_key = ->(category, order) { "#{category}-#{order}" }
    resource_by_key = incident.resources.each_with_object({}) do |r, h|
      h[existing_key.call(r.category, r.order_number.to_s)] = r
    end

    # -- Parents (Resources) --
    parents.each do |row|
      if row[:status] == "D"
        result.demobed_skipped += 1
        next
      end
      if row[:category].nil?
        result.service_skipped += 1
        next
      end

      key = existing_key.call(row[:category], row[:parent_num])
      if resource_by_key.key?(key)
        result.resources_skipped += 1
        next
      end

      # Prefer the CSV values when the newer export columns are populated;
      # otherwise fall back (personnel = count of active child rosters,
      # length = 14). Active-child count deliberately excludes demobed
      # kids so it matches on-incident headcount.
      child_count = children.count do |c|
        c[:parent_num] == row[:parent_num] && c[:prefix] == row[:prefix] && c[:status] != "D"
      end
      personnel = row[:personnel].to_i.positive? ? row[:personnel].to_i : [child_count, 1].max
      length    = row[:assignment_length].to_i.positive? ? row[:assignment_length].to_i : 14

      resource = incident.resources.build(
        category:          row[:category],
        order_number:      row[:parent_num],
        name:              row[:name],
        position:          row[:item_code],
        # Presence-required — some field-hire rows in iSuite have no
        # agency; fall back to a dash so validation passes.
        agency:            row[:agency].presence || "—",
        number_personnel:  personnel,
        assignment_length: length,
        checkin_date:      row[:checkin_date],
        fwd:               row[:fwd],
        r_and_r:           row[:status] == "R"
      )
      if resource.save
        resource_by_key[key] = resource
        result.resources_created += 1
      else
        result.errors << "#{row[:request]}: #{resource.errors.full_messages.join('; ')}"
      end
    end

    # -- Children (Rosters) --
    children.each do |row|
      if row[:status] == "D"
        result.demobed_skipped += 1
        next
      end
      if row[:category].nil?
        result.service_skipped += 1
        next
      end

      parent = resource_by_key[existing_key.call(row[:category], row[:parent_num])]
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

    result
  end

  private

  def parse_rows
    # iSuite exports lead with a UTF-8 BOM. CSV.new's `encoding:` option is
    # unreliable in Ruby 3.1 when the IO already has its own encoding set —
    # slurp the string, strip the BOM manually, then parse.
    raw = @io.respond_to?(:read) ? @io.read : @io.to_s
    raw = raw.force_encoding("UTF-8")
    raw = raw.sub(/\A\xEF\xBB\xBF/, "") # strip BOM if present
    CSV.parse(raw, headers: true).each_with_object([]) do |csv_row, out|
      request = csv_row["Request #"].to_s.strip
      next if request.empty?

      prefix, rest = request.split("-", 2)
      next if rest.nil?

      parent_num, child_num = rest.split(".", 2)

      out << {
        request:      request,
        prefix:       prefix,
        parent_num:   parent_num,
        child_num:    child_num, # nil = parent row
        category:     CATEGORY_FROM_PREFIX[prefix], # nil for S / unknown → treated as service
        name:         csv_row["Resource Name"].to_s.strip,
        item_code:    csv_row["Item Code"].to_s.strip,
        status:       csv_row["Status"].to_s.strip,
        agency:       csv_row["Agency"].to_s.strip,
        item_name:         csv_row["Item Name"].to_s.strip,
        unit_id:           csv_row["Unit ID"].to_s.strip,
        checkin_date:      parse_date(csv_row["Check-In Date"]),
        fwd:               parse_date(csv_row["First Work Day"]),
        assignment_length: csv_row["Length of Assignment"].to_s.strip,
        personnel:         csv_row["# Personnel"].to_s.strip
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
