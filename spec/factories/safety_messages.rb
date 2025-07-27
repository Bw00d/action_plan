FactoryBot.define do
  factory :safety_message do
    hazards {"MyText"}
    narrative {"MyText"}
    prepared_by {"MyString"}
    association :plan
  end
end