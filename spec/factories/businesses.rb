# frozen_string_literal: true

FactoryBot.define do
  factory :business do
    association :user, :confirmed_provider
    name { Faker::Company.name }
    description { Faker::Lorem.paragraph }
    category { ["Beauty & Wellness", "Fitness", "Healthcare"].sample }
    address { Faker::Address.street_address }
    city { Faker::Address.city }
    lat { Faker::Address.latitude }
    lng { Faker::Address.longitude }
    opening_hours do
      {
        "monday" => { "open" => "09:00", "close" => "18:00" },
        "tuesday" => { "open" => "09:00", "close" => "18:00" },
        "wednesday" => { "open" => "09:00", "close" => "18:00" },
        "thursday" => { "open" => "09:00", "close" => "18:00" },
        "friday" => { "open" => "09:00", "close" => "18:00" },
        "saturday" => { "open" => "10:00", "close" => "16:00" },
        "sunday" => { "open" => nil, "close" => nil },
      }
    end

    trait :with_services do
      after(:create) do |business|
        create_list(:service, 3, business: business)
      end
    end

    trait :discarded do
      discarded_at { Time.current }
    end
  end
end
