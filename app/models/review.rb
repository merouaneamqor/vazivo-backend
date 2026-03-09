# frozen_string_literal: true

class Review < ApplicationRecord
  # Associations
  belongs_to :booking, optional: true
  belongs_to :business
  belongs_to :user, optional: true

  # Delegates for Law of Demeter
  delegate :name, to: :user, prefix: true, allow_nil: true
  delegate :avatar_url, to: :user, prefix: :customer, allow_nil: true
  delegate :booking_service_items, to: :booking, prefix: false, allow_nil: true
  delegate :start_time, to: :booking, prefix: :booking, allow_nil: true

  # Constants
  CORE_CATEGORIES = ["cleanliness", "punctuality", "professionalism", "service_quality", "hygiene"].freeze
  PREMIUM_CATEGORIES = ["ambiance", "staff_friendliness", "waiting_time", "value"].freeze
  ALL_CATEGORIES = (CORE_CATEGORIES + PREMIUM_CATEGORIES).freeze

  CATEGORY_WEIGHTS = {
    service_quality: 0.35,
    cleanliness: 0.20,
    professionalism: 0.20,
    punctuality: 0.15,
    hygiene: 0.10,
  }.freeze

  SPAM_KEYWORDS = ["spam", "scam", "fake", "fraud"].freeze

  # Validations
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :booking_id, uniqueness: { message: "already has a review" }, allow_nil: true
  validates :comment, length: { maximum: 2000 }

  validates :cleanliness_rating, :punctuality_rating, :professionalism_rating,
            :service_quality_rating, :hygiene_rating,
            presence: true, inclusion: { in: 1..5 }

  validates :ambiance_rating, :staff_friendliness_rating, :waiting_time_rating, :value_rating,
            inclusion: { in: 1..5 }, allow_nil: true

  validates :photos, length: { maximum: 5 }

  validate :booking_belongs_to_user, if: :booking_id?
  validate :booking_is_completed, if: :booking_id?
  validate :check_spam_content
  validate :cannot_edit_after_24h, on: :update, if: :enforce_time_limit?

  # Callbacks
  before_validation :set_associations
  before_save :calculate_overall_rating
  after_update :track_edit_time
  after_commit :recalculate_business_ratings, on: [:create, :update, :destroy]

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_rating, ->(rating) { where(rating: rating) if rating.present? }
  scope :with_comment, -> { where.not(comment: [nil, ""]) }
  scope :with_photos, -> { where("jsonb_array_length(photos) > 0") }
  scope :approved, -> { where(moderation_status: "approved") }
  scope :pending_moderation, -> { where(moderation_status: "pending") }

  def editable?
    created_at > 24.hours.ago
  end

  def premium_categories_filled?
    [ambiance_rating, staff_friendliness_rating, waiting_time_rating, value_rating].any?(&:present?)
  end

  private

  def calculate_overall_rating
    weighted_sum = CATEGORY_WEIGHTS.sum do |category, weight|
      rating_value = send("#{category}_rating")
      rating_value ? rating_value * weight : 0
    end

    self.rating = weighted_sum.round
  end

  def booking_belongs_to_user
    return if booking.blank? || user.blank?

    errors.add(:base, "You can only review your own bookings") if booking.user_id != user_id
  end

  def booking_is_completed
    return if booking.blank?

    errors.add(:base, "You can only review completed bookings") unless booking.status_completed?
  end

  def set_associations
    return if booking.blank?

    self.business_id ||= booking.business_id
    self.user_id ||= booking.user_id
  end

  def check_spam_content
    return if comment.blank?

    content = comment.downcase
    return unless SPAM_KEYWORDS.any? { |word| content.include?(word) }

    self.moderation_status = "pending"
  end

  def cannot_edit_after_24h
    return if created_at.blank?

    return unless created_at <= 24.hours.ago && (changed - ["updated_at"]).any?

    errors.add(:base, "Reviews cannot be edited after 24 hours")
  end

  def enforce_time_limit?
    caller.none? { |line| line.include?("admin/reviews_controller") }
  end

  def track_edit_time
    self.edited_at = Time.current if saved_change_to_comment? || saved_change_to_rating?
  end

  def recalculate_business_ratings
    return unless business_id
    return unless defined?(RecalculateBusinessRatingsJob)

    RecalculateBusinessRatingsJob.perform_later(business_id)
  end
end
