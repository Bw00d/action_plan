require 'rails_helper'

RSpec.describe Demob, type: :model do
  # Associations
  describe 'associations' do
    it { should belong_to(:resource) }
    it { should have_many(:units).dependent(:destroy) }
  end

  # Callbacks
  describe 'callbacks' do
    describe 'after_create' do
      let(:resource) { create(:resource) }
      let(:demob) { build(:demob, resource: resource) }

      it 'creates 14 units for the demob' do
        demob = create(:demob, resource: resource)
        expect(demob.units.count).to eq(14)
      end

      it 'creates units with correct managers and order' do
        demob = resource.demob
      units = demob.units.order(:order)
      
      expect(units[0].manager).to eq("Supply Unit")
      expect(units[0].order).to eq(1)
        
        expect(units[1].manager).to eq("Communications Unit")
        expect(units[1].order).to eq(2)
        
        expect(units[4].manager).to eq("Security manager")
        expect(units[4].order).to eq(5)
        
        expect(units[5].manager).to eq("")
        expect(units[5].order).to eq(6)
        
        expect(units[12].manager).to eq("Documentation Unit")
        expect(units[12].order).to eq(13)
        
        expect(units[13].manager).to eq("Demob Unit")
        expect(units[13].order).to eq(14)
      end
    end

    describe 'after_update' do
      let(:resource) { create(:resource, release_date: nil) }
      let(:demob) { create(:demob, resource: resource, actual_release_date: nil) }

      context 'when actual_release_date is set' do
        it 'updates the resource release_date' do
          release_date = Date.today
          demob.update(actual_release_date: release_date)
          
          expect(resource.reload.release_date).to eq(release_date)
        end
      end

      context 'when actual_release_date is updated to a new date' do
        it 'updates the resource with new release_date' do
          demob.update(actual_release_date: Date.yesterday)
          expect(resource.reload.release_date).to eq(Date.yesterday)
          
          demob.update(actual_release_date: Date.today)
          expect(resource.reload.release_date).to eq(Date.today)
        end
      end

      context 'when actual_release_date is nil' do
        it 'does not update the resource' do
          demob.update(remarks: 'Some remarks')
          
          expect(resource.reload.release_date).to be_nil
        end
      end

      context 'when other attributes are updated' do
        it 'does not affect resource if actual_release_date is nil' do
          demob.update(destination: 'Home Base')
          
          expect(resource.reload.release_date).to be_nil
        end
      end
    end
  end

  # Instance methods
  describe '#formatted_release_date' do
    context 'with actual_release_date' do
      let(:demob) { build(:demob, actual_release_date: Date.new(2024, 3, 15)) }
      
      it 'returns formatted date as mm/dd' do
        expect(demob.formatted_release_date).to eq('03/15')
      end
    end

    context 'without actual_release_date' do
      let(:demob) { build(:demob, actual_release_date: nil) }
      
      it 'returns nil' do
        expect(demob.formatted_release_date).to be_nil
      end
    end
  end

  # Private methods behavior (tested through callbacks)
  describe 'resource release behavior' do
    let(:resource) { create(:resource) }
    let(:demob) { create(:demob, resource: resource) }

    it 'only updates resource when actual_release_date is present' do
      # Initially no release date
      expect(resource.release_date).to be_nil
      
      # Update without actual_release_date
      demob.update(remarks: 'Not ready yet')
      expect(resource.reload.release_date).to be_nil
      
      # Update with actual_release_date
      demob.update(actual_release_date: Date.today)
      expect(resource.reload.release_date).to eq(Date.today)
    end
  end
end