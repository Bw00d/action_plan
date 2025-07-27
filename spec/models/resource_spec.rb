require 'rails_helper'

RSpec.describe Resource, type: :model do
  # Associations
  describe 'associations' do
    it { should belong_to(:incident) }
    it { should have_one(:demob) }
  end

  # Validations
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:position) }
    it { should validate_presence_of(:agency) }
    it { should validate_presence_of(:order_number) }
    it { should validate_presence_of(:number_personnel) }
    it { should validate_presence_of(:assignment_length) }
    it { should validate_presence_of(:category) }
  end

  # Scopes
  describe 'scopes' do
  let!(:overhead) { create(:resource, category: 'OVERHEAD') }
  let!(:equipment) { create(:resource, category: 'EQUIPMENT') }
  let!(:crew) { create(:resource, category: 'CREW') }
  let!(:aircraft) { create(:resource, category: 'AIRCRAFT') }
  
  # Create these with explicit different categories to avoid conflicts
  let!(:assigned_resource) { create(:resource, category: 'CREW', release_date: nil, r_and_r: false) }
  let!(:released_resource) { create(:resource, category: 'CREW', release_date: Date.today) }
  let!(:rnr_resource) { create(:resource, category: 'CREW', r_and_r: true) }

  describe '.overhead' do
    it 'returns only overhead resources' do
      expect(Resource.overhead).to contain_exactly(overhead)
    end
  end

  describe '.equipment' do
    it 'returns only equipment resources' do
      expect(Resource.equipment).to contain_exactly(equipment)
    end
  end

  describe '.crew' do
    it 'returns only crew resources' do
      # This will now include crew, assigned_resource, released_resource, and rnr_resource
      expect(Resource.crew).to contain_exactly(crew, assigned_resource, released_resource, rnr_resource)
    end
  end

  describe '.aircraft' do
    it 'returns only aircraft resources' do
      expect(Resource.aircraft).to contain_exactly(aircraft)
    end
  end

  describe '.assigned' do
    it 'returns resources without release date and not on R&R' do
      # This should include overhead, equipment, crew, aircraft, and assigned_resource
      # but not released_resource or rnr_resource
      assigned_resources = Resource.assigned
      expect(assigned_resources).to include(overhead, equipment, crew, aircraft, assigned_resource)
      expect(assigned_resources).not_to include(released_resource, rnr_resource)
    end
  end

  describe '.on_rnr' do
    it 'returns only R&R resources' do
      expect(Resource.on_rnr).to contain_exactly(rnr_resource)
    end
  end
end

  # Callbacks
  describe 'callbacks' do
    describe 'after_create' do
      it 'creates a demob record' do
        expect {
          create(:resource)
        }.to change(Demob, :count).by(1)
      end

      it 'associates the demob with the resource' do
        resource = create(:resource)
        expect(resource.demob).to be_a(Demob)
        expect(resource.demob.resource_id).to eq(resource.id)
      end
    end
  end

  # Instance methods
  describe '#cat' do
    it 'returns O- for OVERHEAD' do
      resource = build(:resource, category: 'OVERHEAD')
      expect(resource.cat).to eq('O-')
    end

    it 'returns C- for CREW' do
      resource = build(:resource, category: 'CREW')
      expect(resource.cat).to eq('C-')
    end

    it 'returns E- for EQUIPMENT' do
      resource = build(:resource, category: 'EQUIPMENT')
      expect(resource.cat).to eq('E-')
    end

    it 'returns A- for AIRCRAFT' do
      resource = build(:resource, category: 'AIRCRAFT')
      expect(resource.cat).to eq('A-')
    end

    it 'returns nil for unknown category' do
      resource = build(:resource, category: 'UNKNOWN')
      expect(resource.cat).to be_nil
    end
  end

  describe '#last_work_day' do
    context 'with fwd and assignment_length' do
      let(:resource) { build(:resource, fwd: Date.new(2024, 1, 1), assignment_length: 14) }
      
      it 'returns fwd + assignment_length - 1 day' do
        expect(resource.last_work_day).to eq(Date.new(2024, 1, 14))
      end
    end

    context 'without fwd' do
      let(:resource) { build(:resource, fwd: nil, assignment_length: 14) }
      
      it 'returns a space' do
        expect(resource.last_work_day).to eq(" ")
      end
    end

    context 'without assignment_length' do
      let(:resource) { build(:resource, fwd: Date.new(2024, 1, 1), assignment_length: nil) }
      
      it 'returns a space' do
        expect(resource.last_work_day).to eq(" ")
      end
    end
  end

  describe '#formatted_fwd' do
    context 'with fwd date' do
      let(:resource) { build(:resource, fwd: Date.new(2024, 1, 15)) }
      
      it 'returns formatted date as mm/dd' do
        expect(resource.formatted_fwd).to eq('01/15')
      end
    end

    context 'without fwd date' do
      let(:resource) { build(:resource, fwd: nil) }
      
      it 'returns nil' do
        expect(resource.formatted_fwd).to be_nil
      end
    end
  end

  describe '#formatted_release_date' do
    context 'with release date' do
      let(:resource) { build(:resource, release_date: Date.new(2024, 2, 20)) }
      
      it 'returns formatted date as mm/dd' do
        expect(resource.formatted_release_date).to eq('02/20')
      end
    end

    context 'without release date' do
      let(:resource) { build(:resource, release_date: nil) }
      
      it 'returns nil' do
        expect(resource.formatted_release_date).to be_nil
      end
    end
  end

  describe '#full_order_number' do
    it 'combines category prefix with order number' do
      resource = build(:resource, category: 'OVERHEAD', order_number: '12345')
      expect(resource.full_order_number).to eq('O-12345')
    end
  end

  describe '#released?' do
    context 'with release date' do
      let(:resource) { build(:resource, release_date: Date.today) }
      
      it 'returns true' do
        expect(resource.released?).to be true
      end
    end

    context 'without release date' do
      let(:resource) { build(:resource, release_date: nil) }
      
      it 'returns nil' do
        expect(resource.released?).to be_nil
      end
    end
  end

  describe '#rnr?' do
    context 'when r_and_r is true' do
      let(:resource) { build(:resource, r_and_r: true) }
      
      it 'returns true' do
        expect(resource.rnr?).to be true
      end
    end

    context 'when r_and_r is false' do
      let(:resource) { build(:resource, r_and_r: false) }
      
      it 'returns nil' do
        expect(resource.rnr?).to be_nil
      end
    end
  end
end