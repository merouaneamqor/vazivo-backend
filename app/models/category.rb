# frozen_string_literal: true

class Category < ApplicationRecord
  extend Mobility
  translates :name, backend: :column, locale_accessors: [:en, :fr, :ar]
  translates :slug, backend: :column, locale_accessors: [:en, :fr, :ar]

  LOCALES = %w[en fr ar].freeze
  # Only these 5 top-level categories are used. All businesses must map to one of them.
  CANONICAL_NAMES = ["Salon de Beauté", "Barber", "Hammam", "Massage & Spa", "Nail Salon"].freeze

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, dependent: :destroy
  has_many :business_categories, dependent: :destroy
  has_many :businesses, through: :business_categories

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :at_least_one_name_locale_present, on: :create

  before_validation :backfill_name_en_from_name_if_single_name
  before_validation :backfill_missing_locale_names_from_first_present
  before_validation :sync_locale_slugs_from_names
  before_validation :sync_canonical_name_and_slug
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :acts, -> { where(parent_id: nil) }
  scope :subacts, -> { where.not(parent_id: nil) }
  scope :ordered, -> { order(:position, :name) }

  # Canonical name/slug (stored in DB) for Business, ensure_canonical_acts!, and lookups.
  # Mobility may call these with optional args (e.g. locale); accept and ignore to avoid ArgumentError.
  def name(*)
    read_attribute(:name)
  end

  def slug(*)
    read_attribute(:slug)
  end

  # Resolve any locale slug (or canonical slug) to the category's canonical name.
  def self.canonical_name_for_slug(slug_param)
    return nil if slug_param.blank?

    normalized = slug_param.to_s.parameterize.presence
    return nil if normalized.blank?

    cat = find_by_slug_any_locale(normalized)
    cat ? cat.name : CANONICAL_NAMES.first
  end

  # Ensures exactly the 5 canonical acts exist. When translations are given (e.g. from prod_data load),
  # sets name/slug for en, fr, ar; otherwise sets only name_en/slug_en from CANONICAL_NAMES.
  def self.ensure_canonical_acts!(translations = nil)
    list = translations.presence || CANONICAL_NAMES.map { |name| { en: name, fr: name, ar: name, slug: name.parameterize } }
    list.each_with_index do |t, position|
      slug_val = t[:slug]
      cat = Category.find_or_initialize_by(slug: slug_val)
      cat.name_en = t[:en]
      cat.name_fr = t[:fr]
      cat.name_ar = t[:ar]
      cat.slug_en = slug_val
      cat.slug_fr = slug_val
      cat.slug_ar = slug_val
      cat[:name] = t[:en]
      cat[:slug] = slug_val
      cat.parent_id = nil
      cat.position = position
      cat.save! if cat.new_record? || cat.changed?
      if cat.persisted? && (cat.position != position || cat.parent_id.present?)
        cat.update_columns(position: position, parent_id: nil)
      end
    end

    ids_to_remove = Category.acts.where.not(name: CANONICAL_NAMES).pluck(:id) + Category.subacts.pluck(:id)
    if ids_to_remove.any? && defined?(Service) && Service.table_exists?
      Service.where(category_id: ids_to_remove).update_all(category_id: nil)
    end

    Category.acts.where.not(name: CANONICAL_NAMES).destroy_all
    Category.subacts.destroy_all
  end

  def act?
    parent_id.nil?
  end

  def subact?
    parent_id.present?
  end

  # Returns the category name for the given locale (Mobility columns); falls back to canonical name.
  def translated_name(locale = I18n.locale)
    loc = locale.to_s.downcase
    return name unless LOCALES.include?(loc)

    public_send("name_#{loc}").presence || name
  end

  # Returns the category slug for the given locale (Mobility columns); falls back to canonical slug.
  def translated_slug(locale = I18n.locale)
    loc = locale.to_s.downcase
    return slug unless LOCALES.include?(loc)

    public_send("slug_#{loc}").presence || slug
  end

  # Resolve a business category name or slug to its translated name in the given locale.
  def self.translated_name_for(name_or_slug, locale = I18n.locale)
    return name_or_slug if name_or_slug.blank?

    slug_key = name_or_slug.to_s.parameterize.presence
    return name_or_slug if slug_key.blank?

    cat = find_by_slug_any_locale(slug_key)
    cat ? cat.translated_name(locale) : name_or_slug
  end

  def self.find_by_slug_any_locale(slug_key)
    find_by(slug: slug_key) || find_by(slug_en: slug_key) || find_by(slug_fr: slug_key) || find_by(slug_ar: slug_key)
  end

  private

  def at_least_one_name_locale_present
    return if name_en.present? || name_fr.present? || name_ar.present?
    return if read_attribute(:name).present?

    errors.add(:base, "At least one of name_en, name_fr, or name_ar must be present")
  end

  # When only canonical name is set (e.g. from admin create with single field), fill all locale columns
  # so the category is created "translated" (same value in en, fr, ar).
  def backfill_name_en_from_name_if_single_name
    return unless read_attribute(:name).present? && name_en.blank? && name_fr.blank? && name_ar.blank?

    base = read_attribute(:name)
    self.name_en = base
    self.name_fr = base
    self.name_ar = base
  end

  # When only one locale name is set (e.g. admin entered only EN), copy it to the other locales
  # so the category is fully translated (no blank locales).
  def backfill_missing_locale_names_from_first_present
    present = [name_en, name_fr, name_ar].map(&:presence).compact
    return if present.size != 1

    value = present.first
    self.name_en = value if name_en.blank?
    self.name_fr = value if name_fr.blank?
    self.name_ar = value if name_ar.blank?
  end

  def sync_locale_slugs_from_names
    LOCALES.each do |loc|
      name_val = public_send("name_#{loc}")
      next if name_val.blank?

      base = name_val.parameterize.presence
      next if base.blank?

      col = "slug_#{loc}"
      self[col] = ensure_unique_slug_for_column(col, base)
    end
  end

  def sync_canonical_name_and_slug
    self[:name] = name_en.presence || name_fr.presence || name_ar.presence || read_attribute(:name)
    self[:slug] = slug_en.presence || slug_fr.presence || slug_ar.presence || read_attribute(:slug)
  end

  def ensure_unique_slug_for_column(column, base)
    slug_candidate = base
    counter = 1
    while Category.where(column => slug_candidate).where.not(id: id).exists?
      slug_candidate = "#{base}-#{counter}"
      counter += 1
    end
    slug_candidate
  end

  def generate_slug
    base = read_attribute(:name).to_s.parameterize.presence
    return if base.blank?

    self[:slug] = ensure_unique_slug_for_column("slug", base)
  end
end
