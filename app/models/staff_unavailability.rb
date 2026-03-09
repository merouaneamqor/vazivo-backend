# frozen_string_literal: true

class StaffUnavailability < ApplicationRecord
  belongs_to :business
  belongs_to :user

  validates :business_id, :user_id, :start_time, :end_time, presence: true
  validate :end_time_after_start_time

  scope :for_business_on_date, ->(business_id, date) {
    where(business_id: business_id)
      .where("DATE(start_time) <= ? AND DATE(end_time) >= ?", date, date)
  }

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end
end
