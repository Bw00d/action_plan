
FactoryBot.define do
  factory :plan do
    association :user
    association :incident
    date { Date.today }
  end
end