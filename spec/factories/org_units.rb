FactoryBot.define do
  factory :org_unit do
    incident
    name { 'Operations' }
    kind { :section }

    trait :command do
      kind { :command }
      name { 'Command' }
    end

    trait :section do
      kind { :section }
    end

    trait :branch do
      kind { :branch }
      name { 'Branch I' }
    end

    trait :division do
      kind { :division }
      name { 'Div A' }
    end

    trait :group do
      kind { :group }
      name { 'Structure Group' }
    end
  end
end
