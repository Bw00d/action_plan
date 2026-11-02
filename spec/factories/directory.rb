FactoryBot.define do
  factory :position do
    sequence(:code) { |n| "POS#{n}" }
    title { "Test Position #{code}" }
  end

  factory :qualification do
    user
    position
    status { :qualified }
    source { :self_reported }

    trait :certified do
      source { :certified }
      certified_at { Time.current }
    end
  end

  factory :contact_method do
    user
    kind { :phone }
    label { 'Cell' }
    sequence(:value) { |n| "541-555-#{1000 + n}" }
    shared { false }
  end
end
