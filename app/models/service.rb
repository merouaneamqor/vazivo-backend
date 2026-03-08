# frozen_string_literal: true

class Service < ApplicationRecord
  extend Mobility
  translates :name, backend: :column, locale_accessors: [:en, :fr, :ar]
  translates :description, backend: :column, locale_accessors: [:en, :fr, :ar]

  LOCALES = %w[en fr ar].freeze

  include Discard::Model

  # Associations
  belongs_to :business
  belongs_to :category, optional: true
  belongs_to :service_category
  has_many :booking_service_items, class_name: "BookingServiceItem", dependent: :destroy
  has_many :bookings, through: :booking_service_items
  has_many :staff_services, dependent: :destroy
  has_many :staff_members, through: :staff_services, source: :staff

  # Attachments
  mount_uploader :image, ImageUploader

  # Validations
  validates :duration, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 480 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :service_category, presence: true

  # Scopes
  scope :active, -> { kept }
  scope :by_price_range, ->(min, max) { min.present? && max.present? ? where(price: min.to_f..max.to_f) : self }
  scope :by_duration_range, ->(min, max) { min.present? && max.present? ? where(duration: min.to_i..max.to_i) : self }
  scope :by_parent_category, ->(parent_id) {
    parent_id.present? ? joins(:category).where(categories: { parent_id: parent_id }) : self
  }
  scope :by_service_category, ->(category_id) {
    category_id.present? ? where(service_category_id: category_id) : self
  }
  scope :uncategorized, -> { where(service_category_id: nil) }

  before_validation :backfill_service_locales_from_canonical
  before_validation :sync_canonical_name_description

  # Canonical getters for validations (Mobility may call with optional locale; accept and ignore).
  def name(*)
    read_attribute(:name)
  end

  def description(*)
    read_attribute(:description)
  end

  def translated_name(locale = I18n.locale)
    loc = locale.to_s.downcase
    return name unless LOCALES.include?(loc)

    public_send("name_#{loc}").presence || name
  end

  def translated_description(locale = I18n.locale)
    loc = locale.to_s.downcase
    return description unless LOCALES.include?(loc)

    public_send("description_#{loc}").presence || description
  end

  # Methods

  # Display name: prefer the linked sub-category name, fall back to the service's own name
  def category_name(locale = I18n.locale)
    category&.translated_name(locale) || translated_name(locale)
  end

  def parent_category
    category&.parent
  end

  def parent_category_name(locale = I18n.locale)
    parent_category&.translated_name(locale)
  end

  def parent_category_slug(locale = I18n.locale)
    parent_category&.translated_slug(locale)
  end

  def formatted_duration
    if duration < 60
      "#{duration} min"
    else
      hours = duration / 60
      mins = duration % 60
      mins.positive? ? "#{hours}h #{mins}min" : "#{hours}h"
    end
  end

  def formatted_price
    currency = Rails.application.config.x.app_currency || "MAD"
    "#{price.to_f.round(2)} #{currency}"
  end

  def upcoming_bookings
    bookings.upcoming
  end

  def available_on?(date, start_time)
    AvailabilityService.new(self).available?(date, start_time)
  end

  private

  def backfill_service_locales_from_canonical
    return unless self.class.column_names.include?("name_en")

    if read_attribute(:name).present? && name_en.blank? && name_fr.blank? && name_ar.blank?
      self.name_en = read_attribute(:name)
    end
    if read_attribute(:description).present? && description_en.blank? && description_fr.blank? && description_ar.blank?
      self.description_en = read_attribute(:description)
    end
  end

  def sync_canonical_name_description
    self[:name] = name_en.presence || name_fr.presence || name_ar.presence || read_attribute(:name)
    self[:description] = description_en.presence || description_fr.presence || description_ar.presence || read_attribute(:description)
  end
end
