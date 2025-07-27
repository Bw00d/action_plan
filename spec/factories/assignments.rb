# FactoryBot.define do
#   factory :assignment do
#     designator {"MyString"}
#     control_operations {"MyText"}
#     special_instructions {"MyText"}
#     plan_id {1}
#   end
# end

# spec/factories/assignments.rb
FactoryBot.define do
  factory :assignment do
    association :plan
    designator { "DIV A" }
    ops_period { "0600-1800" }
    control_operations { "Control operations text" }
    special_instructions { "Special instructions text" }
    resource_ids { [] }
    commo_item_ids { [] }
    ops_personnel_ids { [] }
  end
end