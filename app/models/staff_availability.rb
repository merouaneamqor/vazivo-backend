# frozen_string_literal: true

class StaffAvailability < ApplicationRecord
  belongs_to :business
  belongs_to :user

  validates :day_of_week, presence: true, inclusion: { in: 0..6 }
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :day_of_week, uniqueness: { scope: [:business_id, :user_id], message: "already has availability set" }
  validate :end_time_after_start_time

  scope :available, -> { where(available: true) }
  scope :for_day, ->(day) { where(day_of_week: day) }

  DAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"].freeze

  def day_name
    DAY_NAMES[day_of_week]
  end

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end
