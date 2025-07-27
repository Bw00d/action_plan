# FactoryBot.define do
#   factory :team do
#     resource_id {1}
#     position {"MyString"}
#     staff {"MyString"}
#     plan_id {1}
#   end
# end

FactoryBot.define do
  factory :team do
    position {"IC"}
    association :plan
    staff { "Command" }
  end
end