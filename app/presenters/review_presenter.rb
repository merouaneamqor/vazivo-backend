# frozen_string_literal: true

class ReviewPresenter
  attr_reader :review

  delegate :id, :rating, :comment, :created_at, to: :review

  def initialize(review)
    @review = review
  end

  def as_json(*)
    {
      id: id,
      rating: rating,
      comment: comment,
      user: user_info,
      service_name: service_name,
      created_at: created_at,
      helpful_count: helpful_count,
    }
  end

  def user_info
    return nil unless review.user

    {
      id: review.user_id,
      name: review.user_name,
      initials: initials,
    }
  end

  def initials
    return nil unless review.user

    name = review.user_name.to_s.strip
    return "?" if name.blank?

    name.split(/\s+/).map(&:first).join.upcase[0, 2]
  end

  def service_name
    primary_item = review.booking_service_items&.first
    primary_item&.service&.name
  end

  def helpful_count
    # Placeholder for future helpful votes feature
    0
  end
end
