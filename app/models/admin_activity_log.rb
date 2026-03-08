# frozen_string_literal: true

class AdminActivityLog < ApplicationRecord
  belongs_to :admin_user, class_name: "User"

  validates :admin_user_id, presence: true
  validates :action, presence: true
  validates :resource_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_resource_type, ->(type) { where(resource_type: type) if type.present? }
  scope :by_action, ->(action) { where(action: action) if action.present? }
  scope :since, ->(time) { where(created_at: time..) if time.present? }
end
