require 'rails_helper'

RSpec.describe PlanAssignmentSnapshot, type: :model do
  describe 'associations' do
    it { should belong_to(:plan) }
    it { should belong_to(:org_unit) }
    it { should belong_to(:resource) }
  end

  it 'is destroyed when its plan is destroyed' do
    snapshot = create(:plan_assignment_snapshot)
    expect { snapshot.plan.destroy }.to change(PlanAssignmentSnapshot, :count).by(-1)
  end
end
