FactoryBot.define do
  factory :professional do
    sequence(:name) { |n| "Professional #{n}" }
    token { "calendly_token_#{SecureRandom.hex(10)}" }
    sequence(:email) { |n| "professional#{n}@example.com" }
    sequence(:phone) { |n| "+1234567890#{n}" }
    organization { "https://api.calendly.com/organizations/#{SecureRandom.uuid}" }

    trait :without_token do
      token { nil }
    end

    trait :without_organization do
      organization { nil }
    end

    trait :invalid do
      name { nil }
      token { nil }
    end
  end
end