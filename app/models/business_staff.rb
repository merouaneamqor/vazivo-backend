# frozen_string_literal: true

class BusinessStaff < ApplicationRecord
  belongs_to :business
  belongs_to :user

  validates :user_id, uniqueness: { scope: :business_id, message: "is already assigned to this business" }
  validates :role, inclusion: { in: ["owner", "manager", "staff"] }

  scope :active, -> { where(active: true) }
  scope :owners, -> { where(role: "owner") }
  scope :managers, -> { where(role: "manager") }
  scope :staff_only, -> { where(role: "staff") }

  def owner?
    role == "owner"
  end

  def manager?
    role == "manager"
  end
end
