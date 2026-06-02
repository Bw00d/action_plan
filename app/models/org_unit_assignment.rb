class OrgUnitAssignment < ApplicationRecord
  belongs_to :org_unit
  belongs_to :resource

  acts_as_list scope: :org_unit_id, top_of_list: 1, add_new_at: :bottom

  validates :resource_id, uniqueness: true
  validate :resource_and_org_unit_share_incident

  private

  def resource_and_org_unit_share_incident
    return if resource.nil? || org_unit.nil?
    return if resource.incident_id == org_unit.incident_id

    errors.add(:resource, 'must belong to the same incident as the org unit')
  end
end
