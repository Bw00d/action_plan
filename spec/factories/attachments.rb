# spec/factories/attachments.rb
FactoryBot.define do
  factory :attachment do
    association :plan
    description { "Test Attachment" }
  end
end