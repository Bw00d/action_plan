require 'csv'

# Compares an IROC "resources at incident" CSV export against the
# resources checked in to a given incident. Every A/C/E/O row in the
# upload is treated as At Incident (that's what the whole export means
# — no need for a per-row status filter, which was eating rows when
# the CSV used a different status wording). Any A/C/E/O request number
# that isn't matched by one of our incident's resource order numbers
# gets listed as "missing".
#
# Only four categories matter: Aircraft (A), Crews (C), Equipment (E),
# Overhead (O). Anything else is skipped.
class IrocReconciler
  CATEGORY_FROM_PREFIX = {
    'A' => 'AIRCRAFT',
    'C' => 'CREW',
    'E' => 'EQUIPMENT',
    'O' => 'OVERHEAD'
  }.freeze

  # Column name aliases — case- and punctuation-insensitive match.
  COLUMN_ALIASES = {
    request:  ['request number', 'request #', 'request_number', 'request', 'req #', 'req number'],
    name:     ['resource name', 'name', 'resource', 'personnel name'],
    agency:   ['agency', 'home unit', 'provider unit', 'home dispatch'],
    kind:     ['kind', 'catalog item', 'item code', 'kind/type', 'resource kind']
  }.freeze

  # `released_on` is set when the IROC request # maps to one of our
  # resources that's already been demobilized. Lets the view flag "we
  # had them, but they're already gone" instead of lumping it in with
  # "never on our incident".
  MissingRow = Struct.new(:request, :category, :name, :agency, :kind,
                          :released_on,
                          keyword_init: true)

  Result = Struct.new(
    :missing,            # [MissingRow] — on IROC but not currently active on our incident
    :matched_count,      # how many IROC rows did match
    :skipped_bad_prefix, # non-A/C/E/O rows ignored
    :errors,             # parse errors
    keyword_init: true
  )

  def initialize(io)
    @io = io
  end

  def reconcile(incident)
    rows             = parse_rows
    our_set          = build_our_set(incident)
    released_lookup  = build_released_lookup(incident)
    missing          = []
    matched          = 0
    bad_pfx          = 0

    rows.each do |row|
      req = normalize_request(row[:request])
      next if req.blank?

      prefix = req.first.upcase
      unless CATEGORY_FROM_PREFIX.key?(prefix)
        bad_pfx += 1
        next
      end

      if our_set.include?(req)
        matched += 1
      else
        missing << MissingRow.new(
          request:     req,
          category:    CATEGORY_FROM_PREFIX[prefix],
          name:        row[:name],
          agency:      row[:agency],
          kind:        row[:kind],
          released_on: released_lookup[req]   # nil if we never had them
        )
      end
    end

    # Sort by category then request number, numeric-aware (so C-10 comes
    # after C-9, not C-100).
    missing.sort_by! { |m| [m.category, natural_key(m.request)] }

    Result.new(
      missing:            missing,
      matched_count:      matched,
      skipped_bad_prefix: bad_pfx,
      errors:             []
    )
  end

  private

  # Build a lookup Set of our incident's resource full_order_numbers,
  # including subordinates (rosters). IROC exports treat subordinates
  # like C-73.1, C-73.2 as top-level request numbers, but internally
  # they're Roster rows under parent resource C-73 — this reconciler
  # has to look at BOTH or every subordinate shows up as "missing".
  # Skip spacers / released; those go into the released_lookup below.
  def build_our_set(incident)
    set = Set.new
    incident.resources.active.where(spacer: false).includes(:rosters).find_each do |r|
      full = r.full_order_number.to_s.upcase.strip
      set << full if full.present?

      # Subordinates — only count ones that are still here (not released
      # and not promoted into standalone T-cards).
      r.rosters.each do |ros|
        next if ros.released_at.present? || ros.promoted_resource_id.present?
        subfull = ros.full_order_number.to_s.upcase.strip
        set << subfull if subfull.present?
      end
    end
    set
  end

  # Lookup of request# → release date for resources + rosters we have
  # on the incident that are already demobilized. Used to annotate
  # missing rows with "Demobilized — MM/DD/YY" instead of leaving them
  # as "never on our incident".
  def build_released_lookup(incident)
    h = {}
    # Released parent resources.
    incident.resources
            .where.not(release_date: nil)
            .where(spacer: false)
            .find_each do |r|
      full = r.full_order_number.to_s.upcase.strip
      h[full] = r.release_date if full.present?
    end
    # Released subordinates (rosters). released_at is a datetime; take
    # the date portion for display.
    Roster.joins(:resource)
          .where(resources: { incident_id: incident.id })
          .where.not(released_at: nil)
          .includes(:resource)
          .find_each do |ros|
      subfull = ros.full_order_number.to_s.upcase.strip
      h[subfull] = ros.released_at.to_date if subfull.present?
    end
    h
  end

  # Normalize an IROC request number into our "A-NN" form. Handles raw
  # variants like "A 1", "a-1", "A1", "A-01" by stripping spaces +
  # upcasing + removing leading zeros from the numeric half.
  def normalize_request(raw)
    s = raw.to_s.upcase.gsub(/\s+/, '').strip
    return '' if s.empty?

    # Match PREFIX + optional '-' + digits (possibly with '.' for subs).
    m = s.match(/\A([A-Z])-?(\d[\d.\-]*)\z/)
    return s unless m   # fall back to raw-upcased if format is unexpected

    letter  = m[1]
    numeric = m[2].sub(/\A0+(?=\d)/, '')
    "#{letter}-#{numeric}"
  end

  # Natural sort key — split "C-10.3" into ["C-", 10, 3] so numeric
  # segments compare as integers.
  def natural_key(s)
    s.scan(/\d+|\D+/).map { |p| p =~ /\d/ ? p.to_i : p }
  end

  def parse_rows
    text = @io.respond_to?(:read) ? @io.read : @io.to_s
    text = coerce_to_utf8(text)
    # CSV#new is picky about encoding + BOMs; strip a UTF-8 BOM if present.
    text.sub!("\xEF\xBB\xBF".force_encoding('UTF-8'), '')
    csv  = CSV.parse(text, headers: true)
    header_map = build_header_map(csv.headers.to_a)

    csv.map do |row|
      {
        request: row[header_map[:request]],
        name:    header_map[:name]   && row[header_map[:name]],
        agency:  header_map[:agency] && row[header_map[:agency]],
        kind:    header_map[:kind]   && row[header_map[:kind]]
      }
    end
  end

  # Map our internal field names (request, status, …) to the actual CSV
  # column header strings. Case/punctuation-insensitive — compares the
  # cleaned candidate to each alias cleaned the same way.
  def build_header_map(headers)
    normalized = headers.each_with_object({}) do |h, acc|
      acc[clean(h)] = h
    end
    COLUMN_ALIASES.each_with_object({}) do |(field, aliases), out|
      aliases.each do |a|
        key = clean(a)
        if normalized.key?(key)
          out[field] = normalized[key]
          break
        end
      end
    end
  end

  def clean(s)
    s.to_s.downcase.gsub(/[^a-z0-9]/, '')
  end

  # IROC CSVs exported from Windows systems are typically Windows-1252,
  # not UTF-8 — common offenders are curly quotes, en/em dashes, degree
  # signs, non-breaking spaces. Try UTF-8 first (and accept it if it's
  # genuinely clean), otherwise transcode from CP1252. Final fallback
  # replaces any still-invalid bytes with "?" so a single bad character
  # doesn't abort the whole import.
  def coerce_to_utf8(text)
    s = text.dup.force_encoding('UTF-8')
    return s if s.valid_encoding?

    # Windows-1252 superset of ISO-8859-1 — covers almost every Western
    # Windows export we've seen.
    s = text.dup.force_encoding('Windows-1252').encode(
      'UTF-8',
      invalid: :replace, undef: :replace, replace: '?'
    )
    s
  rescue EncodingError
    # Last resort — scrub bytes individually.
    text.dup.force_encoding('UTF-8').scrub('?')
  end
end
