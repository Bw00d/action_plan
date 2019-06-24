require 'rails_helper'

RSpec.describe Objective, type: :model do
  
  it { should respond_to :plan_id }
  it { should respond_to :description }
  it { should respond_to :order }

  it { should belong_to :plan }
end
