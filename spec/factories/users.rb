FactoryBot.define do
  factory :user do
    email { 'hola@enronda.com' }
    password { 'password123' }
    password_confirmation { 'password123' }

    trait :with_invalid_email do
      email { 'invalid@example.com' }
    end
  end
end