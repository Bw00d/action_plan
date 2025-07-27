# FactoryBot.define do
#   factory :commo_item do
#     zone {"MyString"}
#     ch_num {"MyString"}
#     function {"MyString"}
#     channel_name {"MyString"}
#     assignment {"MyString"}
#     rx_freq {"MyString"}
#     rx_tone {"MyString"}
#     tx_freq {"MyString"}
#     tx_tone {"MyString"}
#     mode {"MyString"}
#     commo_plan_id {1}
#   end
# end

FactoryBot.define do
  factory :commo_item do
    association :commo_plan
    zone {"MyString"}
    ch_num {"MyString"}
    function {"MyString"}
    channel_name {"MyString"}
    assignment {"MyString"}
    rx_freq {"MyString"}
    rx_tone {"MyString"}
    tx_freq {"MyString"}
    tx_tone {"MyString"}
    mode {"MyString"}
  end
end

