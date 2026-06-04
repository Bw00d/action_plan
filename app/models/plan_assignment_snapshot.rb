class PlanAssignmentSnapshot < ApplicationRecord
  belongs_to :plan
  belongs_to :org_unit, optional: true
  belongs_to :resource
end
