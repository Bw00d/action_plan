require 'rails_helper'

RSpec.describe Plans::Publish do
  let(:incident) { create(:incident) }
  let(:plan) { create(:plan, incident: incident) }
  let(:operations) { create(:org_unit, :section, incident: incident, name: 'Operations') }
  let(:division_a) do
    create(:org_unit, :division, incident: incident, parent: operations,
           name: 'Div A', designator: 'A')
  end
  let(:division_b) do
    create(:org_unit, :division, incident: incident, parent: operations,
           name: 'Div B', designator: 'B')
  end

  def assign(resource, org_unit)
    create(:org_unit_assignment, org_unit: org_unit, resource: resource)
  end

  it 'snapshots the current org_unit_assignments to the plan' do
    r1 = create(:resource, incident: incident)
    r2 = create(:resource, incident: incident, order_number: 22)
    assign(r1, division_a)
    assign(r2, division_b)

    described_class.call(plan)

    snapshots = plan.assignment_snapshots.order(:org_unit_id, :position).to_a
    expect(snapshots.size).to eq(2)
    expect(snapshots.map { |s| [s.resource_id, s.org_unit_id, s.designator_at_publish] })
      .to match_array([[r1.id, division_a.id, 'A'], [r2.id, division_b.id, 'B']])
  end

  it 'sets published_at' do
    expect { described_class.call(plan) }.to change { plan.reload.published_at }.from(nil)
    expect(plan.published?).to be true
  end

  it 'preserves the snapshot when live assignments change afterward' do
    r1 = create(:resource, incident: incident)
    assign(r1, division_a)
    described_class.call(plan)

    r1.org_unit_assignment.update!(org_unit: division_b)

    snapshot = plan.assignment_snapshots.first
    expect(snapshot.org_unit_id).to eq(division_a.id)
    expect(snapshot.designator_at_publish).to eq('A')
  end

  it 'overwrites the snapshot on republish' do
    r1 = create(:resource, incident: incident)
    assign(r1, division_a)
    described_class.call(plan)
    first_count = plan.assignment_snapshots.count

    r2 = create(:resource, incident: incident, order_number: 22)
    assign(r2, division_b)
    described_class.call(plan)

    expect(plan.reload.assignment_snapshots.count).to eq(2)
    expect(plan.assignment_snapshots.count).not_to eq(first_count)
  end

  it 'produces an empty snapshot when there are no assignments' do
    described_class.call(plan)
    expect(plan.assignment_snapshots).to be_empty
    expect(plan.published?).to be true
  end

  it 'does not include assignments from other incidents' do
    other_incident = create(:incident)
    other_ops = create(:org_unit, :section, incident: other_incident, name: 'Operations')
    other_div = create(:org_unit, :division, incident: other_incident, parent: other_ops)
    other_resource = create(:resource, incident: other_incident)
    create(:org_unit_assignment, org_unit: other_div, resource: other_resource)

    r1 = create(:resource, incident: incident)
    assign(r1, division_a)

    described_class.call(plan)

    expect(plan.assignment_snapshots.pluck(:resource_id)).to contain_exactly(r1.id)
  end
end
