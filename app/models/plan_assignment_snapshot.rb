class PlanAssignmentSnapshot < ApplicationRecord
  belongs_to :plan
  belongs_to :org_unit
  belongs_to :resource
end
