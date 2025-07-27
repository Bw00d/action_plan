FactoryBot.define do
  factory :objective do
    association :plan
    description { "Test Objective" }
    order { 1 }
  end
end

