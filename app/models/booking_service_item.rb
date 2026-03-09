# frozen_string_literal: true

class BookingServiceItem < ApplicationRecord
  self.table_name = "booking_services"

  belongs_to :booking
  belongs_to :service
  belongs_to :staff, class_name: "User", optional: true

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  default_scope { order(position: :asc) }
end
