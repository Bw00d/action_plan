FactoryBot.define do
  factory :incident do
    name { Faker::Color.color_name }
    number { Faker::Number.number(digits: 3) }
    incident_type {"Flood"}
    financial_code { "7321111"}
    complexity {"Type 3"}
    status {"uncontained"}
    cause {"unknown"}
    location {"Boise, ID"}
    ownership {"State"}
    protection {"Critical"}
    ic {Faker::Name.name}
  end
end
