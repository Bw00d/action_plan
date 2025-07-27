FactoryBot.define do
  factory :resource do
    name {"MyString"}
    leader {"MyString"}
    number_personnel { 1 }
    position {"MyString"}
    agency {"MyString"}
    order_number {"MyString"}
    fwd {"2019-08-04"}
    checkin_date {"2019-08-04"}
    assignment_length { 14 }
    association :incident
    category {"Overhead"}
    
    # trait :assigned do
    #   status { 'assigned' }
    # end
    
    # trait :available do
    #   status { 'available' }
    # end
  end
end
