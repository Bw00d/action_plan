# FactoryBot.define do
#   factory :assignment do
#     designator {"MyString"}
#     control_operations {"MyText"}
#     special_instructions {"MyText"}
#     plan_id {1}
#   end
# end

FactoryBot.define do
  factory :assignment do
    association :plan
    designator {"MyString"}
    control_operations {"MyText"}
    special_instructions {"MyText"}
    # Add other required attributes
  end
end
