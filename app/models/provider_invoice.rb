# frozen_string_literal: true

class ProviderInvoice < ApplicationRecord
  belongs_to :business
  belongs_to :subscription, optional: true

  STATUSES = ["pending", "paid"].freeze
  PAYMENT_METHODS = ["stripe", "card", "mtc", "cash", "check", "wire"].freeze

  validates :invoice_id, presence: true, uniqueness: true
  validates :total, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, allow_nil: true

  scope :paid, -> { where(status: "paid") }
  scope :pending, -> { where(status: "pending") }
  scope :for_business, ->(business_id) { where(business_id: business_id) }

  def paid?
    status == "paid"
  end

  def mark_as_paid!(method: nil)
    update!(status: "paid", paid_at: Time.current, payment_method: method || payment_method)
  end

  # Generate a unique invoice ID (INV-YYYYMMDD-XXXXX)
  def self.generate_invoice_id
    loop do
      id = "INV-#{Date.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(5).upcase}"
      break id unless exists?(invoice_id: id)
    end
  end
end
