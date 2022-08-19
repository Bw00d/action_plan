FactoryBot.define do
  factory :post do
    title {"MyString"}
    body {"MyText"}
    posted_at {"2022-07-16 12:59:14"}
    user_id {1}
  end
end
