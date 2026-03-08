# frozen_string_literal: true

FactoryBot.define do
  factory :booking do
    association :user, :customer
    association :service
    business { service.business }
    date { Date.tomorrow }
    start_time { "10:00" }
    status { "pending" }

    trait :confirmed do
      status { "confirmed" }
      confirmed_at { Time.current }
    end

    trait :cancelled do
      status { "cancelled" }
      cancelled_at { Time.current }
    end

    trait :completed do
      status { "completed" }
      completed_at { Time.current }
    end

    trait :past do
      date { Date.yesterday }
    end

    trait :future do
      date { Date.tomorrow + 7.days }
    end
  end
end
