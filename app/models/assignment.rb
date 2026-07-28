class Assignment < ApplicationRecord
  belongs_to :plan
  belongs_to :org_unit, optional: true

  def freqs
    items = []
    if self.commo_item_ids
      self.commo_item_ids.each { |i| items << CommoItem.find(i) }
    end
    items.sort
  end

  # Source-of-truth dispatch:
  # - org_unit_id present + plan published → frozen PlanAssignmentSnapshot
  # - org_unit_id present + plan draft     → live OrgUnitAssignment via the board
  # - org_unit_id nil (legacy)             → string array of resource_ids
  def assigned_resources
    return legacy_assigned_resources if org_unit_id.nil?

    if plan.published?
      ordered_resource_ids = plan.assignment_snapshots
                                 .where(org_unit_id: org_unit_id)
                                 .order(:position)
                                 .pluck(:resource_id)
      Resource.where(id: ordered_resource_ids)
              .index_by(&:id)
              .values_at(*ordered_resource_ids)
              .compact
    else
      org_unit.resources.order('org_unit_assignments.position')
    end
  end

  def personnel
    assigned_resources.sum { |r| r.number_personnel.to_i }
  end

  def branch
    node = org_unit
    node = node.parent while node && !node.kind_branch?
    node
  end

  def ops_period_from=(value)
    super(parse_ops_datetime(value))
  end

  def ops_period_to=(value)
    super(parse_ops_datetime(value))
  end

  def operations_resources
    items = []
    if self.ops_personnel_ids
      self.ops_personnel_ids.each { |i| items << Team.find(i) }
    end
    items
  end

  def update_resources(id)
    if self.ops_personnel_ids && self.ops_personnel_ids.include?(id)
      arr = self.ops_personnel_ids.reject { |e| e == id }
      self.update_attributes(ops_personnel_ids: arr)
    end
  end

  private

  # Accepts "MM/DD/YYYY HHMM" (military time, no colon) as well as anything
  # Time.zone.parse can handle. Returns nil for blank/invalid input.
  def parse_ops_datetime(value)
    return value unless value.is_a?(String)
    return nil if value.blank?

    s = value.strip
    if s =~ %r{\A(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{2})(\d{2})\z}
      Time.zone.local(Regexp.last_match(3).to_i, Regexp.last_match(1).to_i,
                      Regexp.last_match(2).to_i, Regexp.last_match(4).to_i,
                      Regexp.last_match(5).to_i)
    else
      Time.zone.parse(s)
    end
  rescue ArgumentError
    nil
  end

  def legacy_assigned_resources
    return [] if resource_ids.blank?
    by_string_id = Resource.where(id: resource_ids).index_by { |r| r.id.to_s }
    resource_ids.map { |id| by_string_id[id.to_s] }.compact
  end
end
