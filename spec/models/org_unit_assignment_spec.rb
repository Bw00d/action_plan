require 'rails_helper'

RSpec.describe OrgUnitAssignment, type: :model do
  let(:incident) { create(:incident) }
  let(:operations) { create(:org_unit, :section, incident: incident, name: 'Operations') }
  let(:division) { create(:org_unit, :division, incident: incident, parent: operations) }
  let(:resource) { create(:resource, incident: incident) }

  describe 'associations' do
    it { should belong_to(:org_unit) }
    it { should belong_to(:resource) }
  end

  describe 'uniqueness' do
    it 'allows one assignment per resource' do
      create(:org_unit_assignment, org_unit: division, resource: resource)
      second_division = create(:org_unit, :division, incident: incident, parent: operations, name: 'Div B')
      duplicate = build(:org_unit_assignment, org_unit: second_division, resource: resource)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:resource_id]).to include('has already been taken')
    end
  end

  describe 'same-incident validation' do
    it 'rejects assigning a resource from another incident' do
      other_incident = create(:incident)
      foreign_resource = create(:resource, incident: other_incident)
      assignment = build(:org_unit_assignment, org_unit: division, resource: foreign_resource)

      expect(assignment).not_to be_valid
      expect(assignment.errors[:resource]).to include(/same incident/)
    end
  end

  describe 'positioning within an org_unit' do
    it 'orders assignments by position' do
      first = create(:org_unit_assignment, org_unit: division, resource: resource)
      second_resource = create(:resource, incident: incident, order_number: 22)
      second = create(:org_unit_assignment, org_unit: division, resource: second_resource)

      expect(division.org_unit_assignments.pluck(:id)).to eq([first.id, second.id])
      expect(second.position).to eq(2)
    end
  end

  describe 'cascade behavior' do
    it 'is destroyed when its resource is destroyed' do
      assignment = create(:org_unit_assignment, org_unit: division, resource: resource)
      expect { resource.destroy }.to change(OrgUnitAssignment, :count).by(-1)
      expect { assignment.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'is destroyed when its org_unit is destroyed' do
      create(:org_unit_assignment, org_unit: division, resource: resource)
      expect { division.destroy }.to change(OrgUnitAssignment, :count).by(-1)
    end
  end

  describe 'Resource#unassigned scope' do
    it 'finds resources with no org_unit_assignment' do
      assigned = create(:resource, incident: incident)
      create(:org_unit_assignment, org_unit: division, resource: assigned)
      unassigned = create(:resource, incident: incident, order_number: 99)

      expect(Resource.unassigned).to include(unassigned)
      expect(Resource.unassigned).not_to include(assigned)
    end
  end
end
