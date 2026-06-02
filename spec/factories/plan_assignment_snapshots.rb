FactoryBot.define do
  factory :plan_assignment_snapshot do
    plan
    org_unit { create(:org_unit, :section, incident: plan.incident, name: 'Operations') }
    resource { create(:resource, incident: plan.incident) }
    position { 1 }
    designator_at_publish { 'A' }
  end
end
