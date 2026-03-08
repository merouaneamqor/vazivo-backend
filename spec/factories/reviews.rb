# frozen_string_literal: true

FactoryBot.define do
  factory :review do
    association :booking, :completed
    user { booking.user }
    business { booking.business }
    rating { rand(1..5) }
    comment { Faker::Lorem.paragraph }
  end
end
