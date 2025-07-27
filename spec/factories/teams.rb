FactoryBot.define do
  factory :team do
    association :plan
    resource_name { "Engine 1" }
    position { "Squad Boss" }
    staff { "Operations" }
  end
end