FactoryBot.define do
  factory :org_unit_assignment do
    transient do
      incident { create(:incident) }
    end

    org_unit do
      ops = incident.section(:operations) ||
            create(:org_unit, :section, incident: incident, name: 'Operations')
      create(:org_unit, :division, incident: incident, parent: ops)
    end

    resource { create(:resource, incident: org_unit.incident) }
  end
end
