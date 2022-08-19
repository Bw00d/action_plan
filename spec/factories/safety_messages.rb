FactoryBot.define do
  factory :safety_message do
    hazards {"MyText"}
    narrative {"MyText"}
    prodced_by {"MyString"}
    plan_id {1}
  end
end
