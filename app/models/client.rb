# frozen_string_literal: true

class Client < ApplicationRecord
  belongs_to :business
  belongs_to :user, optional: true

  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, length: { maximum: 100 }, allow_blank: true
  validate :at_least_one_contact

  before_save :sync_name_from_first_last

  scope :for_business, ->(business_id) { where(business_id: business_id) }
  scope :search_by, ->(q) {
    return all if q.blank?

    pattern = "%#{q.to_s.strip.downcase}%"
    where(
      "LOWER(name) LIKE :q OR LOWER(first_name) LIKE :q OR LOWER(last_name) LIKE :q OR LOWER(COALESCE(email, '')) LIKE :q OR phone LIKE :q",
      q: pattern
    )
  }

  def name
    [first_name, last_name].compact.join(" ").strip.presence || read_attribute(:name)
  end

  def name=(value)
    parts = value.to_s.strip.split(/\s+/, 2)
    self.first_name = parts[0].presence || first_name
    self.last_name = parts[1].presence
    write_attribute(:name, [first_name, last_name].compact.join(" ").strip)
  end

  private

  def sync_name_from_first_last
    return if first_name.blank?

    write_attribute(:name, [first_name, last_name].compact.join(" ").strip)
  end

  def at_least_one_contact
    return if phone.present? || email.present?

    errors.add(:base, "Phone or email is required")
  end
end
