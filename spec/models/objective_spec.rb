require 'rails_helper'

RSpec.describe Objective, type: :model do
  # Associations
  describe 'associations' do
    it { should belong_to(:plan) }
  end

  # Callbacks
  describe 'callbacks' do
    describe 'before_create' do
      let(:plan) { create(:plan) }

      context 'when plan has no objectives' do
        it 'sets order to 1' do
          objective = create(:objective, plan: plan)
          expect(objective.order).to eq(1)
        end
      end

      context 'when plan has existing objectives' do
        let!(:first_objective) { create(:objective, plan: plan, order: 1) }
        let!(:second_objective) { create(:objective, plan: plan, order: 2) }

        it 'sets order to last order + 1' do
          new_objective = create(:objective, plan: plan)
          expect(new_objective.order).to eq(3)
        end
      end

      context 'when objectives have non-sequential orders' do
      it 'sets order based on the highest existing order' do
        # Create objectives without specifying order - let the callback set them
        obj1 = create(:objective, plan: plan) # order will be 1
        obj2 = create(:objective, plan: plan) # order will be 2
        obj3 = create(:objective, plan: plan) # order will be 3
        
        # Manually update one to have a higher order
        obj3.update_column(:order, 10) # bypass callbacks
        
        # Now create a new objective
        new_objective = create(:objective, plan: plan)
        expect(new_objective.order).to eq(11)
      end
    end
      context 'when creating multiple objectives' do
        it 'increments order for each new objective' do
          obj1 = create(:objective, plan: plan)
          obj2 = create(:objective, plan: plan)
          obj3 = create(:objective, plan: plan)

          expect(obj1.order).to eq(1)
          expect(obj2.order).to eq(2)
          expect(obj3.order).to eq(3)
        end
      end

      context 'when updating an existing objective' do
        let!(:objective) { create(:objective, plan: plan, description: 'Original') }
        
        it 'does not change the order' do
          original_order = objective.order
          objective.update(description: 'Updated')
          expect(objective.reload.order).to eq(original_order)
        end
      end
    end
  end

  # Instance methods
  describe '#set_order' do
    let(:plan) { create(:plan) }

    it 'is called before create' do
      objective = build(:objective, plan: plan)
      expect(objective).to receive(:set_order)
      objective.save
    end

    it 'does not override manually set order on update' do
      objective = create(:objective, plan: plan, order: 10)
      expect(objective.order).to eq(1) # set_order overrides on create
      
      # But on update, it should keep the current order
      objective.description = 'Updated'
      objective.save
      expect(objective.order).to eq(1)
    end
  end

  # Edge cases
  describe 'edge cases' do
    let(:plan) { create(:plan) }

    context 'when objectives are deleted' do
      let!(:obj1) { create(:objective, plan: plan) }
      let!(:obj2) { create(:objective, plan: plan) }
      let!(:obj3) { create(:objective, plan: plan) }

      it 'still increments from the highest remaining order' do
        expect(obj3.order).to eq(3)
        obj2.destroy
        
        new_objective = create(:objective, plan: plan)
        expect(new_objective.order).to eq(4) # continues from 3, not fills gap at 2
      end
    end
  end
end