# spec/factories/commo_plans.rb
FactoryBot.define do
  factory :commo_plan do
    association :plan
    ops_period { "0600-1800" }
    date_prepared { Date.today.to_s }
    prepared_by { "Test Preparer" }
  end
end
