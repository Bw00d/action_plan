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

  # True when the req_number contains a dot — indicates this request sits
  # somewhere beneath a root parent in the request tree.
  def subordinate?
    req_number.to_s.include?('.')
  end

  # Direct parent's req_number ("E-209.3.1" → "E-209.3", "E-209.3" → "E-209",
  # "E-24" → "E-24" (self, no parent)).
  def parent_req_number
    req_number.to_s.sub(/\.[^.]+\z/, '')
  end

  # Numeric portion of req_number for the check-in form's Resource#
  # order_number pre-fill. Strips the "X-" category prefix; whatever
  # remains ("24", "209.3", "1.5", etc.) is the order number.
  def suggested_order_number
    req_number.to_s.sub(/\A[A-Z]-/, '').presence
  end

  # Group an incident's requests as { parent_req_number => [Request, ...] }.
  # Useful for the requests index tree and for populating a Roster from a
  # strike team's subordinates on check-in.
  def self.build_children_map(requests)
    map = Hash.new { |h, k| h[k] = [] }
    requests.each do |r|
      next unless r.subordinate?
      map[r.parent_req_number] << r
    end
    map
  end

  # All descendants of req_num walked depth-first in natural numeric order
  # at every level, so C-3.1, C-3.2, ..., C-3.10 land in the right sequence
  # regardless of insertion order in the IROC dump. Used both to size the
  # # of personnel and to populate the Roster on check-in.
  def self.descendants_of(req_num, children_map)
    result = []
    direct_children_of(req_num, children_map).each do |kid|
      result << kid
      result.concat(descendants_of(kid.req_number, children_map))
    end
    result
  end

  # Direct subordinates natural-sorted so ".1" comes before ".10" and the
  # numerically first one lands at the head of the list (i.e. the leader).
  def self.direct_children_of(req_num, children_map)
    (children_map[req_num] || []).sort_by do |r|
      r.req_number.to_s.scan(/\d+/).map(&:to_i)
    end
  end

  # Pre-fill for Resource#name on the check-in form.
  #   Person → "LAST, FIRST" (upcased to match the app's resource naming style)
  #   Otherwise → res_name (already carries crew/equipment display name)
  def suggested_resource_name
    if person?
      [last_name, first_name].reject(&:blank?).map(&:upcase).join(', ')
    else
      res_name
    end
  end
end
