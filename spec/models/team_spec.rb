require 'rails_helper'

RSpec.describe Team, type: :model do
  # Associations
  describe 'associations' do
    it { should belong_to(:plan) }
  end

  # Callbacks
  describe 'callbacks' do
    describe 'after_destroy' do
      let(:plan) { create(:plan) }
      let(:team) { create(:team, plan: plan) }
      let(:team2) { create(:team, plan: plan) }
      let(:team3) { create(:team, plan: plan) }

      context 'when team is referenced in assignments' do
        let!(:assignment1) { create(:assignment, plan: plan, ops_personnel_ids: [team.id.to_s, team2.id.to_s]) }
        let!(:assignment2) { create(:assignment, plan: plan, ops_personnel_ids: [team.id.to_s, team3.id.to_s]) }
        let!(:assignment3) { create(:assignment, plan: plan, ops_personnel_ids: [team2.id.to_s, team3.id.to_s]) }

        it 'removes team id from all assignments' do
          team.destroy
          
          expect(assignment1.reload.ops_personnel_ids).to eq([team2.id.to_s])
          expect(assignment2.reload.ops_personnel_ids).to eq([team3.id.to_s])
          expect(assignment3.reload.ops_personnel_ids).to eq([team2.id.to_s, team3.id.to_s])
        end

        it 'removes team id from assignments when destroyed' do
          # Verify initial state
          expect(assignment1.ops_personnel_ids).to include(team.id.to_s)
          expect(assignment2.ops_personnel_ids).to include(team.id.to_s)
          
          # Destroy the team
          team.destroy
          
          # Verify the team id was removed
          expect(assignment1.reload.ops_personnel_ids).not_to include(team.id.to_s)
          expect(assignment2.reload.ops_personnel_ids).not_to include(team.id.to_s)
          expect(assignment3.reload.ops_personnel_ids).not_to include(team.id.to_s)
        end
      end

      context 'when team is not referenced in any assignments' do
        let!(:assignment) { create(:assignment, plan: plan, ops_personnel_ids: [team2.id.to_s]) }

        it 'does not modify assignments' do
          original_ids = assignment.ops_personnel_ids.dup
          team.destroy
          expect(assignment.reload.ops_personnel_ids).to eq(original_ids)
        end
      end

      context 'when assignments have nil ops_personnel_ids' do
        let!(:assignment) { create(:assignment, plan: plan, ops_personnel_ids: nil) }

        it 'does not raise error' do
          expect { team.destroy }.not_to raise_error
        end
      end

      context 'when assignments have empty ops_personnel_ids' do
        let!(:assignment) { create(:assignment, plan: plan, ops_personnel_ids: []) }

        it 'does not raise error' do
          expect { team.destroy }.not_to raise_error
        end
      end
    end
  end

  # Instance methods
  describe '#update_204' do
    let(:plan) { create(:plan) }
    let(:team) { create(:team, plan: plan) }

    context 'with multiple assignments' do
      let!(:assignment1) { create(:assignment, plan: plan, ops_personnel_ids: [team.id.to_s, '999']) }
      let!(:assignment2) { create(:assignment, plan: plan, ops_personnel_ids: ['888', team.id.to_s]) }

      it 'updates all assignments containing the team id' do
        team.update_204
        
        expect(assignment1.reload.ops_personnel_ids).to eq(['999'])
        expect(assignment2.reload.ops_personnel_ids).to eq(['888'])
      end
    end

    context 'when called manually (not through destroy)' do
      let!(:assignment) { create(:assignment, plan: plan, ops_personnel_ids: [team.id.to_s]) }

      it 'still removes the team id from assignments' do
        team.update_204
        expect(assignment.reload.ops_personnel_ids).to eq([])
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    let(:plan) { create(:plan) }
    let(:team) { create(:team, plan: plan) }

    context 'when team belongs to a different plan' do
      let(:other_plan) { create(:plan) }
      let!(:other_assignment) { create(:assignment, plan: other_plan, ops_personnel_ids: [team.id.to_s]) }
      let!(:same_plan_assignment) { create(:assignment, plan: plan, ops_personnel_ids: [team.id.to_s]) }

      it 'only updates assignments in the same plan' do
        team.destroy
        
        # Should update assignment in same plan
        expect(same_plan_assignment.reload.ops_personnel_ids).to eq([])
        
        # Should NOT update assignment in different plan
        expect(other_assignment.reload.ops_personnel_ids).to eq([team.id.to_s])
      end
    end
  end
end