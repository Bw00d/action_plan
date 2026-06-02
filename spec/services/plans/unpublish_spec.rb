require 'rails_helper'

RSpec.describe Plans::Unpublish do
  let(:incident) { create(:incident) }
  let(:plan) { create(:plan, incident: incident) }
  let(:operations) { create(:org_unit, :section, incident: incident, name: 'Operations') }
  let(:division) { create(:org_unit, :division, incident: incident, parent: operations) }

  before do
    resource = create(:resource, incident: incident)
    create(:org_unit_assignment, org_unit: division, resource: resource)
    Plans::Publish.call(plan)
  end

  it 'clears the snapshot rows and the published_at timestamp' do
    expect(plan.assignment_snapshots).to be_present
    expect(plan.published?).to be true

    described_class.call(plan)

    expect(plan.reload.assignment_snapshots).to be_empty
    expect(plan.published_at).to be_nil
    expect(plan.draft?).to be true
  end
end
