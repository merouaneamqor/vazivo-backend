# frozen_string_literal: true

class ServiceCategory < ApplicationRecord
  belongs_to :business
  has_many :services, dependent: :nullify

  validates :name, presence: true, length: { maximum: 100 }
  validates :color, format: { with: /\A#[0-9A-F]{6}\z/i }, if: -> { color.present? }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :ordered, -> { order(:position, :name) }

  def archive!
    update(archived_at: Time.current)
  end

  def unarchive!
    update(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end

  def services_count
    services.active.count
  end
end
