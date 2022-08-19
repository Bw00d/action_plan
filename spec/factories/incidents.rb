FactoryBot.define do
  factory :incident do
    name { Faker::Color.color_name }
    number { Faker::Number.number(digits: 3) }
    incident_type {"Flood"}
  end
end
