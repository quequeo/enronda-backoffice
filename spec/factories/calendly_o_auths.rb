FactoryBot.define do
  factory :calendly_o_auth do
    access_token { "access_token_#{SecureRandom.hex(10)}" }
    refresh_token { "refresh_token_#{SecureRandom.hex(10)}" }
    owner { SecureRandom.uuid }
    organization { "https://api.calendly.com/organizations/#{SecureRandom.uuid}" }

    trait :expired do
      access_token { "expired_token_#{SecureRandom.hex(10)}" }
    end

    trait :without_refresh_token do
      refresh_token { nil }
    end
  end
end