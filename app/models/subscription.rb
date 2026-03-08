# frozen_string_literal: true

class Subscription < ApplicationRecord
  belongs_to :business
  has_many :provider_invoices, dependent: :nullify

  STATUSES = ["active", "expired", "cancelled"].freeze
  PAID_VIA_OPTIONS = ["stripe", "card", "mtc", "cash", "check", "wire"].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :plan_id, presence: true
  validates :paid_via, presence: true, inclusion: { in: PAID_VIA_OPTIONS }
  validates :started_at, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where(status: "active").where("expires_at > ?", Time.current) }
  scope :expired, -> { where(expires_at: ..Time.current).or(where(status: "expired")) }
  scope :for_business, ->(business_id) { where(business_id: business_id) }

  def active?
    status == "active" && expires_at > Time.current
  end

  def expired?
    expires_at <= Time.current
  end

  def expire!
    update!(status: "expired")
  end

  def cancel!
    update!(status: "cancelled")
  end
end
