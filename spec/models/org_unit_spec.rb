require 'rails_helper'

RSpec.describe OrgUnit, type: :model do
  let(:incident) { create(:incident) }

  describe 'associations' do
    it { should belong_to(:incident) }
    it { should belong_to(:parent).class_name('OrgUnit') }
    it { should have_many(:children).class_name('OrgUnit').dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:org_unit, incident: incident) }
    it { should validate_presence_of(:name) }
  end

  describe 'kind enum' do
    it 'defines the ICS org levels' do
      expect(described_class.kinds.keys).to match_array(%w[command section branch division group])
    end
  end

  describe 'parent kind validation' do
    let(:operations) { create(:org_unit, :section, incident: incident, name: 'Operations') }
    let(:branch) { create(:org_unit, :branch, incident: incident, parent: operations, name: 'Branch I') }

    it 'allows a section with no parent' do
      unit = build(:org_unit, :section, incident: incident, parent: nil, name: 'Plans')
      expect(unit).to be_valid
    end

    it 'allows a branch under a section' do
      unit = build(:org_unit, :branch, incident: incident, parent: operations, name: 'Branch I')
      expect(unit).to be_valid
    end

    it 'rejects a branch under a division' do
      division = create(:org_unit, :division, incident: incident, parent: operations, name: 'Div A')
      unit = build(:org_unit, :branch, incident: incident, parent: division, name: 'Bad Branch')
      expect(unit).not_to be_valid
    end

    it 'allows a division under a branch' do
      unit = build(:org_unit, :division, incident: incident, parent: branch, name: 'Div A')
      expect(unit).to be_valid
    end

    it 'rejects a division at the root' do
      unit = build(:org_unit, :division, incident: incident, parent: nil, name: 'Orphan Div')
      expect(unit).not_to be_valid
    end
  end

  describe 'positioning' do
    it 'orders children by position via acts_as_list' do
      ops = create(:org_unit, :section, incident: incident, name: 'Operations')
      first = create(:org_unit, :division, incident: incident, parent: ops, name: 'Div A')
      second = create(:org_unit, :division, incident: incident, parent: ops, name: 'Div B')

      expect(ops.children.pluck(:id)).to eq([first.id, second.id])
      expect(second.position).to eq(2)
    end
  end
end
