class StaffService < ApplicationRecord
  belongs_to :business
  belongs_to :staff, class_name: "User"
  belongs_to :service

  validates :business_id, :staff_id, :service_id, presence: true
  validates :business_id, uniqueness: { scope: [:staff_id, :service_id] }
  validate :service_belongs_to_business

  def effective_price
    price_override.presence || service.price
  end

  def effective_duration
    duration_override.presence || service.duration
  end

  private

  def service_belongs_to_business
    return if service.blank? || business_id.blank?

    errors.add(:service, "must belong to the same business") if service.business_id != business_id
  end
end

