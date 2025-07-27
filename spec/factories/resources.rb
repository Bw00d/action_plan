# spec/factories/resources.rb
FactoryBot.define do
  factory :resource do
    association :incident
    name { "Test Resource" }
    position { "Squad Boss" }
    agency { "USFS" }
    order_number { "12345" }
    number_personnel { 5 }
    assignment_length { 14 }
    category { "OVERHEAD" }
    fwd { Date.today }
    release_date { nil }
    r_and_r { false }
  end
end