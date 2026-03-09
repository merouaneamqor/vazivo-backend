# frozen_string_literal: true

class Neighborhood < ApplicationRecord
  extend Mobility

  translates :name, backend: :column, locale_accessors: [:en, :fr, :ar]
  translates :slug, backend: :column, locale_accessors: [:en, :fr, :ar]

  LOCALES = ["en", "fr", "ar"].freeze

  belongs_to :city

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :city_id }

  before_validation :backfill_neighborhood_locales_from_canonical
  before_validation :sync_locale_slugs_from_names
  before_validation :sync_canonical_name_and_slug
  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :ordered, -> { order(:position, :name) }

  def name(*)
    read_attribute(:name)
  end

  def slug(*)
    read_attribute(:slug)
  end

  def translated_name(locale = I18n.locale)
    loc = locale.to_s.downcase
    return name unless LOCALES.include?(loc)

    public_send("name_#{loc}").presence || name
  end

  def translated_slug(locale = I18n.locale)
    loc = locale.to_s.downcase
    return slug unless LOCALES.include?(loc)

    public_send("slug_#{loc}").presence || slug
  end

  private

  def backfill_neighborhood_locales_from_canonical
    return unless self.class.column_names.include?("name_en")

    if read_attribute(:name).present? && name_en.blank? && name_fr.blank? && name_ar.blank?
      self.name_en = read_attribute(:name)
    end
    return unless read_attribute(:slug).present? && slug_en.blank? && slug_fr.blank? && slug_ar.blank?

    self.slug_en = read_attribute(:slug)
  end

  def sync_locale_slugs_from_names
    LOCALES.each do |loc|
      name_val = public_send("name_#{loc}")
      next if name_val.blank?

      base = name_val.to_s.parameterize.presence
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
    scope = city_id ? Neighborhood.where(city_id: city_id) : Neighborhood.none
    while scope.where(column => slug_candidate).where.not(id: id).exists?
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
