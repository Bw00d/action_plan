require 'rails_helper'

RSpec.describe Incident, type: :model do
  # Associations
  describe 'associations' do
    it { should have_many(:plans).dependent(:destroy) }
    it { should have_many(:resources).dependent(:destroy) }
    it { should have_many(:checkins) }
    it { should have_many(:org_units).dependent(:destroy) }
    it { should have_and_belong_to_many(:users) }
  end

  describe '#section' do
    let(:incident) { create(:incident) }

    before { Incidents::SeedOrgChart.call(incident) }

    it 'finds a seeded section by name' do
      expect(incident.section(:operations).kind).to eq('section')
      expect(incident.section(:operations).name).to eq('Operations')
    end

    it 'returns nil for an unseeded section' do
      expect(incident.section(:nonexistent)).to be_nil
    end
  end

  describe '#owner' do
    let(:user) { create(:user) }
    let(:incident) { create(:incident, owner: user) }
    
    it 'returns the user who owns the incident' do
      expect(incident.owner).to eq(user)
    end
  end

  # Instance methods
  describe '#display_incident_name' do
    let(:incident) { build(:incident, name: 'Big Fire', incident_type: 'Wildfire', number: '123') }
    
    it 'returns formatted incident name' do
      expect(incident.display_incident_name).to eq('Big Fire  –  Wildfire 123')
    end
  end

  describe '#wildfire?' do
    context 'when incident_type is Wildfire' do
      let(:incident) { build(:incident, incident_type: 'Wildfire') }
      
      it 'returns true' do
        expect(incident.wildfire?).to be true
      end
    end
    
    context 'when incident_type is not Wildfire' do
      let(:incident) { build(:incident, incident_type: 'Flood') }
      
      it 'returns nil' do
        expect(incident.wildfire?).to be_nil
      end
    end
  end

  describe '#total_resources' do
    let(:incident) { create(:incident) }
    
    context 'with assigned resources' do
      before do
        create(:resource, incident: incident, number_personnel: 10)
        create(:resource, incident: incident, number_personnel: 5)
      end
      
      it 'sums personnel from assigned resources only' do
        expect(incident.total_resources).to eq(15)
      end
    end
    
    context 'with no resources' do
      it 'returns 0' do
        expect(incident.total_resources).to eq(0)
      end
    end
  end

  describe '#owner' do
    let(:user) { create(:user) }
    let(:incident) { create(:incident, user_id: user.id) }
    
    it 'returns the user who owns the incident' do
      expect(incident.owner).to eq(user)
    end
    
    # Note: This will raise an error if user_id doesn't exist
    # You might want to handle this case in the model
  end
end