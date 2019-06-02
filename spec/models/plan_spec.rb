require 'rails_helper'

RSpec.describe Plan, type: :model do

  let(:user) { FactoryGirl.build(:user) }
  let(:plan) { FactoryGirl.build(:plan) }

  it { should respond_to :date }
  it { should respond_to :user_id }

end
