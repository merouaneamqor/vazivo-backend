# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    password { "password123" }
    password_confirmation { "password123" }
    role { "customer" }

    trait :customer do
      role { "customer" }
    end

    trait :provider do
      role { "provider" }
    end

    trait :confirmed_provider do
      role { "provider" }
      provider_status { "confirmed" }
    end

    trait :admin do
      role { "admin" }
    end

    trait :discarded do
      discarded_at { Time.current }
    end
  end
end
