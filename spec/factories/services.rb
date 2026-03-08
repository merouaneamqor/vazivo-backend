# frozen_string_literal: true

FactoryBot.define do
  factory :service do
    association :business
    name { Faker::Commerce.product_name }
    description { Faker::Lorem.sentence }
    duration { [30, 45, 60, 90, 120].sample }
    price { Faker::Commerce.price(range: 20..200) }

    trait :discarded do
      discarded_at { Time.current }
    end
  end
end
