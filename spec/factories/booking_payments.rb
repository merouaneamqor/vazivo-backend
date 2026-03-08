# frozen_string_literal: true

FactoryBot.define do
  factory :booking_payment, class: "BookingPayment" do
    association :booking
    user { booking.user }
    amount { booking.total_price || Faker::Commerce.price(range: 20..200) }
    status { "pending" }
    stripe_payment_intent_id { "pi_#{SecureRandom.alphanumeric(24)}" }

    trait :pending do
      status { "pending" }
    end

    trait :processing do
      status { "processing" }
    end

    trait :succeeded do
      status { "succeeded" }
      paid_at { Time.current }
    end

    trait :failed do
      status { "failed" }
    end

    trait :refunded do
      status { "refunded" }
      paid_at { 1.day.ago }
      refunded_at { Time.current }
    end
  end
end
