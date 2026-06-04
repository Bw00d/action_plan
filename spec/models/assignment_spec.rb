require 'rails_helper'

RSpec.describe Assignment, type: :model do
  # Associations
  describe 'associations' do
    it { should belong_to(:plan) }
  end

  # Instance methods
  describe '#freqs' do
    let(:plan) { create(:plan) }
    let(:commo_plan) { create(:commo_plan, plan: plan) }
    let!(:commo_item1) { create(:commo_item, commo_plan: commo_plan, ch_num: '2') }
    let!(:commo_item2) { create(:commo_item, commo_plan: commo_plan, ch_num: '1') }
    let!(:commo_item3) { create(:commo_item, commo_plan: commo_plan, ch_num: '3') }

    context 'with commo_item_ids' do
      let(:assignment) { create(:assignment, plan: plan, commo_item_ids: [commo_item2.id.to_s, commo_item1.id.to_s]) }
      
      it 'returns CommoItem objects for the ids' do
        expect(assignment.freqs).to contain_exactly(commo_item1, commo_item2)
      end
      
      it 'returns items sorted' do
        expect(assignment.freqs).to eq([commo_item1, commo_item2].sort)
      end
    end

    context 'without commo_item_ids' do
      let(:assignment) { create(:assignment, plan: plan, commo_item_ids: nil) }
      
      it 'returns empty array' do
        expect(assignment.freqs).to eq([])
      end
    end

    context 'with empty commo_item_ids array' do
      let(:assignment) { create(:assignment, plan: plan, commo_item_ids: []) }
      
      it 'returns empty array' do
        expect(assignment.freqs).to eq([])
      end
    end
  end

  describe '#assigned_resources' do
    let(:incident) { create(:incident) }
    let(:plan) { create(:plan, incident: incident) }
    let!(:resource1) { create(:resource, incident: incident) }
    let!(:resource2) { create(:resource, incident: incident) }
    let!(:resource3) { create(:resource, incident: incident) }

    context 'with valid resource_ids' do
      let(:assignment) { create(:assignment, plan: plan, resource_ids: [resource1.id.to_s, resource2.id.to_s]) }
      
      it 'returns Resource objects for the ids' do
        expect(assignment.assigned_resources).to contain_exactly(resource1, resource2)
      end
    end

    context 'with some invalid resource_ids' do
      let(:assignment) { create(:assignment, plan: plan, resource_ids: [resource1.id.to_s, '99999']) }
      
      it 'returns only valid Resource objects' do
        expect(assignment.assigned_resources).to contain_exactly(resource1)
      end
    end

    context 'without resource_ids' do
      let(:assignment) { create(:assignment, plan: plan, resource_ids: nil) }
      
      it 'returns empty array' do
        expect(assignment.assigned_resources).to eq([])
      end
    end
  end

  describe '#personnel' do
    let(:incident) { create(:incident) }
    let(:plan) { create(:plan, incident: incident) }
    let!(:resource1) { create(:resource, incident: incident, number_personnel: 5) }
    let!(:resource2) { create(:resource, incident: incident, number_personnel: 10) }
    let!(:resource3) { create(:resource, incident: incident, number_personnel: 3) }

    context 'with resources' do
      let(:assignment) { create(:assignment, plan: plan, resource_ids: [resource1.id.to_s, resource2.id.to_s, resource3.id.to_s]) }
      
      it 'sums personnel from all resources' do
        expect(assignment.personnel).to eq(18)
      end
    end

    context 'with one resource' do
      let(:assignment) { create(:assignment, plan: plan, resource_ids: [resource1.id.to_s]) }
      
      it 'returns personnel count for that resource' do
        expect(assignment.personnel).to eq(5)
      end
    end

    context 'without resources' do
      let(:assignment) { create(:assignment, plan: plan, resource_ids: nil) }
      
      it 'returns 0' do
        expect(assignment.personnel).to eq(0)
      end
    end
  end

  describe '#assigned_resources with org_unit (board-sourced)' do
    let(:incident) { create(:incident) }
    let(:plan) { create(:plan, incident: incident) }
    let(:operations) { create(:org_unit, :section, incident: incident, name: 'Operations') }
    let(:division) { create(:org_unit, :division, incident: incident, parent: operations, name: 'Div A', designator: 'A') }
    let!(:resource1) { create(:resource, incident: incident, number_personnel: 5) }
    let!(:resource2) { create(:resource, incident: incident, number_personnel: 10) }

    before do
      create(:org_unit_assignment, org_unit: division, resource: resource1)
      create(:org_unit_assignment, org_unit: division, resource: resource2)
    end

    context 'with a draft plan' do
      let(:assignment) { create(:assignment, plan: plan, org_unit: division) }

      it 'reads live OrgUnitAssignments for the org_unit' do
        expect(assignment.assigned_resources).to contain_exactly(resource1, resource2)
      end

      it 'sums personnel from the board' do
        expect(assignment.personnel).to eq(15)
      end

      it 'ignores the legacy resource_ids array' do
        assignment.update!(resource_ids: ['99999'])
        expect(assignment.assigned_resources).to contain_exactly(resource1, resource2)
      end
    end

    context 'with a published plan' do
      let(:assignment) { create(:assignment, plan: plan, org_unit: division) }

      before do
        assignment # ensure it exists pre-publish so snapshot has something to lock
        Plans::Publish.call(plan)
      end

      it 'reads the frozen snapshot, not the live board' do
        # Mutate the live board after publish
        resource1.org_unit_assignment.destroy
        expect(assignment.assigned_resources.map(&:id)).to contain_exactly(resource1.id, resource2.id)
      end

      it 'still sums personnel from the snapshot' do
        resource1.org_unit_assignment.destroy
        expect(assignment.personnel).to eq(15)
      end
    end
  end

  describe '#operations_resources' do
    let(:plan) { create(:plan) }
    let!(:team1) { create(:team, plan: plan, staff: 'Operations') }
    let!(:team2) { create(:team, plan: plan, staff: 'Plans') }
    let!(:team3) { create(:team, plan: plan, staff: 'Logistics') }

    context 'with ops_personnel_ids' do
      let(:assignment) { create(:assignment, plan: plan, ops_personnel_ids: [team1.id.to_s, team3.id.to_s]) }
      
      it 'returns Team objects for the ids' do
        expect(assignment.operations_resources).to contain_exactly(team1, team3)
      end
    end

    context 'without ops_personnel_ids' do
      let(:assignment) { create(:assignment, plan: plan, ops_personnel_ids: nil) }
      
      it 'returns empty array' do
        expect(assignment.operations_resources).to eq([])
      end
    end
  end

  describe '#update_resources' do
    let(:plan) { create(:plan) }
    let!(:team1) { create(:team, plan: plan) }
    let!(:team2) { create(:team, plan: plan) }
    let!(:team3) { create(:team, plan: plan) }
    let(:assignment) { create(:assignment, plan: plan, ops_personnel_ids: [team1.id.to_s, team2.id.to_s, team3.id.to_s]) }

    context 'when id is in ops_personnel_ids' do
      it 'removes the id from ops_personnel_ids' do
        assignment.update_resources(team2.id.to_s)
        expect(assignment.reload.ops_personnel_ids).to contain_exactly(team1.id.to_s, team3.id.to_s)
      end
    end

    context 'when id is not in ops_personnel_ids' do
      it 'does not change ops_personnel_ids' do
        assignment.update_resources('99999')
        expect(assignment.reload.ops_personnel_ids).to contain_exactly(team1.id.to_s, team2.id.to_s, team3.id.to_s)
      end
    end

    context 'when ops_personnel_ids is nil' do
      let(:assignment) { create(:assignment, plan: plan, ops_personnel_ids: nil) }
      
      it 'does not raise error' do
        expect { assignment.update_resources('123') }.not_to raise_error
      end
    end
  end
end