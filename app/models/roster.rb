class Roster < ApplicationRecord
  belongs_to :resource
  belongs_to :request, optional: true
  belongs_to :promoted_resource, class_name: 'Resource', optional: true

  before_validation :default_agency_from_resource, on: :create

  scope :active,     -> { where(released_at: nil) }
  scope :released,   -> { where.not(released_at: nil) }
  scope :unpromoted, -> { where(promoted_resource_id: nil) }
  scope :promoted,   -> { where.not(promoted_resource_id: nil) }

  default_scope { order(:position_num, :order_number) }

  def released?
    released_at.present?
  end

  def promoted?
    promoted_resource_id.present?
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
end
