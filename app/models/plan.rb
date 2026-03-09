# frozen_string_literal: true

class Plan < ApplicationRecord
  extend Mobility

  translates :name, backend: :column, locale_accessors: [:en, :fr, :ar]

  LOCALES = ["en", "fr", "ar"].freeze

  validates :name, presence: true
  validates :identifier, presence: true, uniqueness: true
  validates :duration_months, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :currency, presence: true
  validates :active, inclusion: { in: [true, false] }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :backfill_plan_locales_from_canonical
  before_validation :sync_canonical_name

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }

  def name(*)
    read_attribute(:name)
  end

  def translated_name(locale = I18n.locale)
    loc = locale.to_s.downcase
    return name unless LOCALES.include?(loc)

    public_send("name_#{loc}").presence || name
  end

  private

  def backfill_plan_locales_from_canonical
    return unless self.class.column_names.include?("name_en")

    return unless read_attribute(:name).present? && name_en.blank? && name_fr.blank? && name_ar.blank?

    self.name_en = read_attribute(:name)
  end

  def sync_canonical_name
    self[:name] = name_en.presence || name_fr.presence || name_ar.presence || read_attribute(:name)
  end
end
