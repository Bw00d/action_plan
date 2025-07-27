FactoryBot.define do
  factory :demob do
    association :resource
    remarks { "Test remarks" }
    edd { Date.tomorrow }
    edt { "0800" }
    destination { "Home Station" }
    travel_method { "POV" }
    manifest { false }
    ron { false }
    actual_release_date { nil }
    actual_release_time { nil }
  end
end