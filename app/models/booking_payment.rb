# frozen_string_literal: true

# Customer payment for a single booking (Stripe PaymentIntent). Not used for provider/subscription payments.
class BookingPayment < ApplicationRecord
  belongs_to :booking
  belongs_to :user

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: ["pending", "processing", "succeeded", "failed", "refunded"] }

  enum :status, {
    pending: "pending",
    processing: "processing",
    succeeded: "succeeded",
    failed: "failed",
    refunded: "refunded",
  }, prefix: true

  scope :successful, -> { where(status: :succeeded) }
  scope :pending, -> { where(status: :pending) }

  def mark_as_paid!
    update!(status: :succeeded, paid_at: Time.current)
  end

  def mark_as_failed!
    update!(status: :failed)
  end

  def refund!
    update!(status: :refunded, refunded_at: Time.current)
  end
end
