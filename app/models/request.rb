class Request < ApplicationRecord
  belongs_to :incident

  validates :iroc_req_id, presence: true, uniqueness: true

  # Personnel rows carry name + employment data; resource rows (aircraft,
  # equipment, supply) don't. Catalog name is the cleanest discriminator.
  PERSONNEL_CATALOGS = %w[Overhead Crew].freeze

  # IROC catalog name → Resource category constant. Supply is intentionally
  # absent: we don't check supplies in as Resources.
  CATALOG_TO_RESOURCE_CATEGORY = {
    'Overhead'  => 'OVERHEAD',
    'Crew'      => 'CREW',
    'Equipment' => 'EQUIPMENT',
    'Aircraft'  => 'AIRCRAFT'
  }.freeze

  scope :personnel, -> { where(req_catalog_name: PERSONNEL_CATALOGS) }
  scope :non_personnel, -> { where.not(req_catalog_name: PERSONNEL_CATALOGS) }
  scope :root_requests, -> { where(root_req_flag: true) }

  # True when this request line represents a named person.
  def person?
    last_name.present?
  end

  # "Last, First Middle" — handy when you later spin up Resource records.
  def full_name
    return res_name unless person?

    given = [first_name, middle_name].reject(&:blank?).join(" ")
    [last_name, given].reject(&:blank?).join(", ")
  end

  # Category to pre-fill on the resource form. nil for Supply (not checkinable).
  def resource_category
    CATALOG_TO_RESOURCE_CATEGORY[req_catalog_name]
  end

  # Supply requests don't get Resource records.
  def checkinable?
    resource_category.present?
  end

  # Subordinate requests have a "." in the number (e.g. "C-1.5"); their tie
  # to a Resource requires decimal order numbers, which the Resource model
  # doesn't currently support. Skip check-in for those.
  def subordinate?
    req_number.to_s.include?('.')
  end

  # Numeric portion of req_number, used as Resource.order_number.
  #   "E-24"  → 24
  #   "C-1"   → 1
  # Returns nil for subordinates.
  def suggested_order_number
    return nil if subordinate?

    match = req_number.to_s.match(/\A[A-Z]-(\d+)\z/)
    match && match[1].to_i
  end

  # Pre-fill for Resource#name on the check-in form.
  #   Person → "Last, First"
  #   Otherwise → res_name (already carries crew/equipment display name)
  def suggested_resource_name
    if person?
      [last_name, first_name].reject(&:blank?).join(', ')
    else
      res_name
    end
  end
end
