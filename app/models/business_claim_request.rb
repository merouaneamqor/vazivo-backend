# frozen_string_literal: true

class BusinessClaimRequest < ApplicationRecord
  belongs_to :business
  belongs_to :user, optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { minimum: 2, maximum: 200 }
  validates :message, length: { maximum: 2000 }, allow_blank: true
  validates :status, inclusion: { in: ["pending", "approved", "rejected"] }

  scope :pending, -> { where(status: "pending") }
end
