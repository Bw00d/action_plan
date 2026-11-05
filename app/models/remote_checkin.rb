# A self-reported, pre-check-in submission from an arriving resource.
# Filled out through the public /remote_checkin/:token form (no login).
# A Plans/OSC user later reviews the submission on the admin queue and
# clicks "Check In" to promote it into a real Resource through the
# existing RequestCheckinsController flow — that's when the official
# roster + state changes happen.
class RemoteCheckin < ApplicationRecord
  broadcasts_incident_changes 'check-ins'
  belongs_to :incident
  # Matched by req_number at submit time; nullable because the resource
  # may have arrived before the request landed in the incident.
  belongs_to :request, optional: true
  # The Resource created when the admin promoted this submission.
  belongs_to :promoted_resource, class_name: 'Resource', optional: true

  enum status: { pending: 0, promoted: 1, dismissed: 2 }

  TRANSPORTATION_METHODS = [
    'Private Vehicle', 'Agency Vehicle', 'Rental',
    'NERV', 'Air', 'Ground Support', 'Other'
  ].freeze

  CATEGORY_PREFIXES = { 'C' => 'CREW', 'E' => 'EQUIPMENT',
                        'O' => 'OVERHEAD', 'A' => 'AIRCRAFT' }.freeze

  # Fields the public best_in_place form on the review page may update
  # on a draft. Omits identifiers (incident_id, request_id, status),
  # audit timestamps, and the derived overhead-single flag — those are
  # set by the controller based on the step flow, not editable text.
  EDITABLE_DRAFT_FIELDS = %w[
    name position agency agency_address email leader phone
    emergency_contact mobilization_date number_personnel
    other_crew_members other_incident_name other_incident_req_number
    first_day_worked first_work_day demob_city demob_state
    transportation_method
  ].freeze

  validates :incident, presence: true
  # Submissions without a submitted_at are drafts in session — only
  # persisted records are fully committed to the queue.
  validates :submitted_at, presence: true, on: :commit_submission

  before_validation :derive_category_from_req_number
  before_validation :normalize_req_number

  scope :pending_first, -> { order(status: :asc, submitted_at: :desc) }
  # A row with no submitted_at is still a draft in the resource's
  # browser — the admin queue should only see rows the resource
  # finished and clicked Submit on.
  scope :submitted, -> { where.not(submitted_at: nil) }

  # Derive OVERHEAD/CREW/EQUIPMENT/AIRCRAFT from whatever the resource
  # typed, even if the request number doesn't exist on this incident.
  def self.category_for(req_number_raw)
    return nil if req_number_raw.blank?
    prefix = req_number_raw.to_s.strip[0]&.upcase
    CATEGORY_PREFIXES[prefix]
  end

  # Convenience for the admin preview UI.
  def display_req_number
    request&.req_number.presence || req_number_raw
  end

  def matched_request?
    request_id.present?
  end

  # Look the request number up again — e.g. after an IROC import brought
  # in the request this resource checked in against. Returns the
  # matched Request, or nil.
  def rematch!
    normalize_req_number
    req = incident.requests.find_by(req_number: req_number_raw)
    return nil unless req
    update!(request: req, category: req.resource_category.presence || category)
    req
  end

  # "C-12" → "12": the Resource#order_number half of the typed number,
  # for checking in without a matched request.
  def typed_order_number
    req_number_raw.to_s.sub(/\A[CEOA]-/, '')
  end

  # The crew/overhead-group leader for the final roster. For single
  # overhead resources the form captures that the person is their own
  # leader, so fall through to their own name.
  def effective_leader
    leader.presence || name
  end

  private

  def derive_category_from_req_number
    return if category.present?
    self.category = self.class.category_for(req_number_raw)
  end

  # Normalize "C 3", "c3", "C3" → "C-3". IROC's canonical form is
  # "<PREFIX>-<NUM>"; matching against Request#req_number requires the
  # dash. The raw form is kept in req_number_raw for the audit trail.
  def normalize_req_number
    return if req_number_raw.blank?
    s = req_number_raw.to_s.strip.upcase.gsub(/\s+/, '')
    if s =~ /\A([CEOA])-?(\d+(?:\.\d+)?)\z/
      self.req_number_raw = "#{$1}-#{$2}"
    end
  end
end
