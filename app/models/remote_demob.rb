# A self-reported demob travel plan from a departing resource. Filled
# out through the public /remote_demob/:token form (no login). The
# Plans section sees submissions on the Plans page and clicks DMB to
# open the resource's ICS-221 with these answers filled in; saving that
# form marks the submission applied.
class RemoteDemob < ApplicationRecord
  broadcasts_incident_changes 'demobs'
  belongs_to :incident
  belongs_to :resource, optional: true
  # Set when the request number is a subordinate (e.g. C-10.3) — the
  # DMB then opens that roster entry's own demob.
  belongs_to :roster, optional: true
  belongs_to :demob, optional: true

  enum status: { pending: 0, applied: 1, dismissed: 2 }

  # Spelled out on the public form (resources may not know the
  # acronyms); stored as the code the Plans section writes on the 221.
  TRAVEL_METHODS = {
    'Privately Owned Vehicle' => 'POV',
    'Agency Vehicle'          => 'AOV',
    'Rental'                  => 'Rental',
    'Air'                     => 'Air',
    'Ground Support'          => 'GS'
  }.freeze
  TRAVEL_METHOD_CODES = TRAVEL_METHODS.values.freeze

  # Resource#transportation_method (from check-in) uses a slightly
  # different list; map the overlap so the demob form can pre-select it.
  CHECKIN_TRAVEL_METHODS = {
    'Private Vehicle' => 'POV',
    'Agency Vehicle'  => 'AOV',
    'Rental'          => 'Rental',
    'Air'             => 'Air',
    'Ground Support'  => 'GS'
  }.freeze

  PREFIXES = { 'C' => 'CREW', 'E' => 'EQUIPMENT', 'O' => 'OVERHEAD', 'A' => 'AIRCRAFT' }.freeze

  validates :travel_method, inclusion: { in: TRAVEL_METHOD_CODES }, allow_blank: true

  before_validation :normalize_req_number

  scope :submitted, -> { where.not(submitted_at: nil) }
  scope :newest_first, -> { order(submitted_at: :desc) }

  # "c 10", "C10", "c-10.3" → "C-10" / "C-10.3". Anything else is
  # returned stripped and upcased so it still displays sensibly.
  def self.normalize_req_number(raw)
    s = raw.to_s.strip.upcase.gsub(/\s+/, '')
    s =~ /\A([CEOA])-?(\d+(?:\.\d+)?)\z/ ? "#{$1}-#{$2}" : s
  end

  # Find what a request number points at on this incident. Returns
  # [resource, roster] — roster is set for a subordinate number such as
  # "C-10.3" (a roster on C-10). Either may be nil.
  def self.match(incident, req_number)
    normalized = normalize_req_number(req_number)
    return [nil, nil] unless normalized =~ /\A([CEOA])-(\d+)(?:\.(\d+))?\z/
    category, parent_num, child_num = PREFIXES[$1], $2, $3

    resources = incident.resources.where(category: category)
    # A promoted subordinate is its own Resource with order_number "10.3",
    # so try the full number as a resource first.
    full_num = [parent_num, child_num].compact.join('.')
    resource = resources.where(order_number: full_num).order(:release_date).first
    return [resource, nil] if resource
    return [nil, nil] unless child_num

    parent = resources.where(order_number: parent_num).order(:release_date).first
    return [nil, nil] unless parent
    # Rosters store either "10.3" or a bare "3".
    roster = parent.rosters.unpromoted.find_by(order_number: [full_num, child_num])
    roster ? [parent, roster] : [nil, nil]
  end

  # "POV" → "Privately Owned Vehicle", for the resource's review screen.
  def self.travel_method_label(code)
    TRAVEL_METHODS.key(code) || code
  end

  def matched?
    resource_id.present?
  end

  # Try the request number again — a submission can arrive before the
  # resource is checked in.
  def rematch!
    resource, roster = self.class.match(incident, req_number_raw)
    update!(resource: resource, roster: roster) if resource
  end

  def display_req_number
    roster&.full_order_number || resource&.full_order_number || req_number_raw
  end

  # The ICS-221 the DMB button opens — the roster entry's own demob for
  # a subordinate, otherwise the resource's.
  def target_demob
    roster ? roster.demob_or_create : resource&.demob
  end

  # ICS-221 fields this submission fills. Blank answers are left out so
  # they don't wipe anything already typed on the demob.
  def demob_attributes
    {
      travel_method:          travel_method,
      edd:                    travel_start_date,
      edt:                    travel_start_time,
      destination:            destination,
      ron:                    ron,
      ron_location:           ron ? ron_location : nil,
      estimated_arrival_date: arrival_date,
      eta:                    arrival_time,
      contact_enroute:        phone
    }.reject { |key, value| key != :ron && value.blank? }
  end

  private

  def normalize_req_number
    self.req_number_raw = self.class.normalize_req_number(req_number_raw) if req_number_raw.present?
  end
end
