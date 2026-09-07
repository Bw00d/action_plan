class Roster < ApplicationRecord
  belongs_to :resource
  belongs_to :request, optional: true
  belongs_to :promoted_resource, class_name: 'Resource', optional: true
  # Roster demobs live in the same demobs table as resource demobs, keyed
  # by roster_id. dependent: :destroy keeps the ICS-221 sheet tied to the
  # roster's lifetime; note the parent resource's demob is untouched.
  has_one :demob, dependent: :destroy

  before_validation :default_agency_from_resource, on: :create
  # Create an ICS-221 demob sheet up front, same as Resource does. Users
  # can print the sheet before they know the release date; the demob's
  # after_update callback wires up the release + notification once the
  # actual release date is finally entered.
  after_create :ensure_demob

  scope :active,     -> { where(released_at: nil) }
  scope :released,   -> { where.not(released_at: nil) }
  scope :unpromoted, -> { where(promoted_resource_id: nil) }
  scope :promoted,   -> { where.not(promoted_resource_id: nil) }

  default_scope { order(:position_num, :order_number) }

  def released?
    released_at.present?
  end

  # Display-ready order number for the ICS-211 roster row. Rosters
  # imported from IROC requests store the full dotted number ("3.1") in
  # order_number; iSuite-imported rosters store just the trailing child
  # ("1") because the CSV row is "C-3.1" split into parent "3" and child
  # "1". Compose the parent piece in when it's missing so both paths
  # render "C-3.1", "C-3.10", etc.
  def full_order_number
    prefix = resource.cat
    return "#{prefix}#{order_number}" if order_number.to_s.include?('.')
    "#{prefix}#{resource.order_number}.#{order_number}"
  end

  # Natural-numeric sort key. order_number is a string, so the DB's
  # lexicographic sort puts "10" before "2". This scan/split preserves
  # insertion-friendly ordering for both "3.1"-style and bare-number
  # rosters.
  def natural_sort_key
    order_number.to_s.scan(/\d+/).map(&:to_i)
  end

  def promoted?
    promoted_resource_id.present?
  end

  # Mark this roster entry as released and drop them from the parent's
  # personnel count. .active scope filters released rows out; the parent's
  # personnel_by_agency uses rosters.active.unpromoted so the tally
  # updates automatically. Idempotent — a repeat call leaves the original
  # released_at in place.
  def release!(at: Time.current)
    return if released?
    update!(released_at: at)
  end

  # Prefill values for a subordinate demob notification form.
  def demob_prefill
    {
      request_number:       full_order_number,
      unit_id:              agency.presence || resource.agency,
      name:                 name.presence   || position,
      actual_release_date:  Time.zone.today
    }
  end

  # Legacy rosters (created before the has_one :demob wiring) won't have
  # a demob record — build one on demand. Idempotent — returns the
  # existing record if already there.
  def demob_or_create
    demob || create_demob!(resource_id: resource_id)
  end

  # Carve this roster entry into its own single-person OVERHEAD Resource so
  # it can be dragged around on the board like a standalone T-card.
  # The parent's tally skips promoted rosters so the personnel counts don't
  # double up. Demob of the parent does NOT cascade to promoted subs.
  def promote!
    raise "already promoted" if promoted?

    new_resource = resource.incident.resources.create!(
      name:              name.presence            || resource.name,
      leader:            name.presence            || resource.leader,
      position:          position.presence        || resource.position,
      agency:            agency.presence          || resource.agency,
      order_number:      derive_promoted_order_number,
      number_personnel:  1,
      assignment_length: resource.assignment_length,
      category:          'OVERHEAD',
      checkin_date:      resource.checkin_date,
      fwd:               resource.fwd
    )
    update!(promoted_resource_id: new_resource.id)
    new_resource
  end

  private

  # Order numbers are unique per (incident, category). Prefer the roster's
  # own order_number, then fall back to "parent.order-position_num".
  def derive_promoted_order_number
    candidate = order_number.presence || "#{resource.order_number}-#{position_num}"
    incident  = resource.incident
    return candidate unless incident.resources.where(category: 'OVERHEAD', order_number: candidate).exists?

    suffix = 2
    suffix += 1 while incident.resources.where(category: 'OVERHEAD', order_number: "#{candidate}-#{suffix}").exists?
    "#{candidate}-#{suffix}"
  end

  # Rosters imported from a subordinate Request will already have their own
  # agency (res_prov_agency_abbrev). For hand-created rosters, inherit the
  # parent resource's agency so the tally can group without a nil bucket.
  def default_agency_from_resource
    self.agency = resource&.agency if agency.blank?
  end

  # after_create callback — create the ICS-221 demob sheet automatically
  # for every new roster row (mirrors Resource#create_demob).
  def ensure_demob
    create_demob!(resource_id: resource_id)
  end
end
