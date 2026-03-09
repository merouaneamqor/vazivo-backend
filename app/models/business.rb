# frozen_string_literal: true

class Business < ApplicationRecord
  extend Mobility

  translates :name, backend: :column, locale_accessors: [:en, :fr, :ar]
  translates :description, backend: :column, locale_accessors: [:en, :fr, :ar]
  translates :slug, backend: :column, locale_accessors: [:en, :fr, :ar]

  LOCALES = ["en", "fr", "ar"].freeze

  # Provider
  include Discard::Model
  include StorageUrlHelper

  # H3 resolution for location index (res 8 ≈ 0.5 km edge length)
  H3_RESOLUTION = 8
  H3_KM_PER_RING = 0.5

  # Associations
  belongs_to :user
  belongs_to :city, optional: true, autosave: false
  belongs_to :neighborhood, optional: true
  has_many :services, dependent: :destroy
  has_many :service_categories, dependent: :destroy
  has_many :bookings, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :business_staff, dependent: :destroy
  has_many :staff_members, through: :business_staff, source: :user
  has_many :staff_availabilities, dependent: :destroy
  has_many :staff_unavailabilities, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :provider_invoices, dependent: :destroy
  has_many :business_claim_requests, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_one :statistic, class_name: "BusinessStatistic", dependent: :destroy
  has_many :business_categories, dependent: :destroy
  has_many :categories, through: :business_categories
  has_many :staff_services, dependent: :destroy

  # CarrierWave uploaders for images
  mount_uploader :logo, ImageUploader
  # For gallery images, use JSONB field: gallery_images (array of {url, public_id})

  # Callbacks
  before_validation :backfill_business_locales_from_canonical
  before_validation :sync_canonical_name_description_slug
  before_validation :sync_category_from_categories
  before_validation :generate_slug_if_needed
  before_validation :set_h3_index_from_coordinates
  before_save :normalize_opening_hours_to_arrays, if: :opening_hours_changed?
  # Callback to sync geo_validated from coordinates
  before_save :set_geo_validated_from_coordinates, if: :lat_or_lng_changed?
  before_save :update_onboarding_score, if: :onboarding_score_column?
  after_create :add_owner_as_staff
  after_commit :enqueue_geocode_if_address_changed, on: [:create, :update]
  after_commit :enqueue_search_index_update, on: [:create, :update]

  # Validations
  validates :name, presence: true, length: { maximum: 200 }
  validates :category, presence: true, if: -> { self.class.column_names.include?("category") }
  validates :address, presence: true
  validates :city_id, presence: true, if: -> { self.class.column_names.include?("city_id") }
  validates :city, presence: true, if: -> { !self.class.column_names.include?("city_id") }
  validates :lat, numericality: { allow_nil: true }
  validates :lng, numericality: { allow_nil: true }
  validates :slug, presence: true, uniqueness: true
  validates :verification_status, inclusion: { in: ["verified", "pending"] }, allow_nil: true

  # Scopes
  scope :active, -> { kept }
  scope :confirmed_provider, -> { joins(:user).where(users: { provider_status: "confirmed" }) }
  scope :premium, -> { where("premium_expires_at > ?", Time.current) }
  scope :by_verification_status, ->(status) { status.present? ? where(verification_status: status) : self }
  scope :find_by_slug!, ->(slug) { kept.find_by!(slug: slug) }
  scope :by_category, ->(category) {
    return none if category.blank?

    # Resolve slug or translated name to canonical name so filtering works across locales
    canonical = defined?(Category) && Category.respond_to?(:canonical_name_for_slug) ? Category.canonical_name_for_slug(category.to_s.parameterize) : nil
    cat = canonical.presence || category
    cat = cat.downcase
    where(
      "LOWER(category) = ? OR EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(categories) AS elem
        WHERE LOWER(elem) = ?
      )",
      cat, cat
    )
  }
  scope :by_city, ->(city_param) {
    if city_param.present?
      param = city_param.to_s.downcase
      left_joins(:city).where(
        "LOWER(businesses.city) = :c OR LOWER(cities.slug) = :c OR LOWER(cities.name) = :c OR LOWER(cities.slug_en) = :c",
        c: param
      )
    else
      self
    end
  }
  scope :search, ->(query) {
    query.present? ? where("businesses.name ILIKE ? OR businesses.description ILIKE ?", "%#{query}%", "%#{query}%") : self
  }
  scope :by_min_rating, ->(rating) {
    if rating.present?
      if column_names.include?("average_rating")
        where("businesses.average_rating >= ?", rating.to_f)
      else
        joins(:reviews).group("businesses.id").having("AVG(reviews.rating) >= ?", rating.to_f)
      end
    else
      self
    end
  }
  scope :by_price_range, ->(min, max) {
    if min.present? && max.present?
      # Use subquery to find businesses with services in price range
      # This avoids GROUP BY issues when combined with other joins
      business_ids = Service.kept
        .joins(:business)
        .merge(Business.kept)
        .where(price: min.to_f..max.to_f)
        .select(:business_id)
        .distinct
        .pluck(:business_id)
      where(id: business_ids)
    else
      self
    end
  }
  scope :near, ->(lat, lng, radius_km = 10) {
    return none unless lat.present? && lng.present?

    hex_indexes = h3_hex_indexes_for_radius(lat.to_f, lng.to_f, radius_km.to_f)
    return none if hex_indexes.empty?

    where(h3_index: hex_indexes)
  }

  # Canonical getters for validations and search (Mobility may call with optional locale; accept and ignore).
  def name(*)
    read_attribute(:name)
  end

  def description(*)
    read_attribute(:description)
  end

  def slug(*)
    read_attribute(:slug)
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

  def translated_slug(locale = I18n.locale)
    loc = locale.to_s.downcase
    return slug unless LOCALES.include?(loc)

    public_send("slug_#{loc}").presence || slug
  end

  # Full address string for geocoding (address, neighborhood, city, country).
  # Prefer read_attribute(:city) when city_id is set to avoid loading the City association (e.g. during seed).
  def geocoding_address
    neighborhood_name = respond_to?(:neighborhood) && neighborhood.respond_to?(:name) ? neighborhood&.name : read_attribute(:neighborhood)
    city_name = if self.class.column_names.include?("city_id") && city_id.present?
                  read_attribute(:city)
                else
                  respond_to?(:city) && city.respond_to?(:name) ? city&.name : read_attribute(:city)
                end
    parts = [address, neighborhood_name, city_name, country].compact_blank
    parts.join(", ").presence
  end

  # Methods (use preloaded associations when loaded to avoid N+1)
  def average_rating
    if self.class.column_names.include?("average_rating") && !read_attribute(:average_rating).nil?
      read_attribute(:average_rating).to_f
    elsif reviews.loaded?
      approved_reviews = reviews.select { |r| r.moderation_status == "approved" }
      return 0.0 if approved_reviews.empty?

      (approved_reviews.map(&:rating).compact.sum.to_f / approved_reviews.size).round(1)
    else
      reviews.approved.average(:rating)&.round(1) || 0.0
    end
  end

  def total_reviews
    if self.class.column_names.include?("reviews_count") && !read_attribute(:reviews_count).nil?
      read_attribute(:reviews_count).to_i
    elsif reviews.loaded?
      reviews.count { |r| r.moderation_status == "approved" }
    else
      reviews.approved.count
    end
  end

  def active_services
    services.kept
  end

  # Returns array of { "open" => "09:00", "close" => "18:00" } for the day.
  # Supports legacy single-interval hash or new array format.
  def intervals_for_day(day)
    raw = (opening_hours || {})[day]
    return [] if raw.blank?

    if raw.is_a?(Array)
      raw.filter_map do |h|
        next unless h.is_a?(Hash)

        open_val = h["open"].presence || h[:open].presence
        close_val = h["close"].presence || h[:close].presence
        { "open" => open_val.to_s, "close" => close_val.to_s } if open_val.present? && close_val.present?
      end
    else
      open_val = raw["open"].presence || raw[:open].presence
      close_val = raw["close"].presence || raw[:close].presence
      open_val.present? && close_val.present? ? [{ "open" => open_val.to_s, "close" => close_val.to_s }] : []
    end
  end

  def is_open?(datetime = Time.current)
    day = datetime.strftime("%A").downcase
    current_time = datetime.strftime("%H:%M")
    intervals_for_day(day).any? { |int| current_time >= int["open"] && current_time < int["close"] }
  end

  def today_hours
    day = Time.current.strftime("%A").downcase
    intervals = intervals_for_day(day)
    intervals.first
  end

  def min_service_price
    if services.loaded?
      kept = services.select(&:kept?)
      kept.any? ? kept.map(&:price).compact.min : nil
    else
      services.kept.minimum(:price)
    end
  end

  def max_service_price
    if services.loaded?
      kept = services.select(&:kept?)
      kept.any? ? kept.map(&:price).compact.max : nil
    else
      services.kept.maximum(:price)
    end
  end

  # CarrierWave image URLs
  def logo_url
    logo.url if logo.present?
  end

  # Gallery images stored as JSONB: [{url: string, public_id: string}]
  def image_urls
    (gallery_images || []).map { |img| img["url"] }.compact
  end

  def add_gallery_image(url, public_id)
    self.gallery_images ||= []
    self.gallery_images << { "url" => url, "public_id" => public_id }
    save
  end

  def remove_gallery_image(public_id)
    self.gallery_images ||= []
    initial_size = self.gallery_images.size
    self.gallery_images.reject! { |img| img["public_id"] == public_id }
    changed = self.gallery_images.size < initial_size
    save if changed
    changed
  end

  def premium?
    premium_expires_at.present? && premium_expires_at > Time.current
  end

  def current_subscription
    subscriptions.active.order(expires_at: :desc).first
  end

  # Generate a URL-friendly slug from name and city (uses canonical name).
  # Prefer read_attribute(:city) when city_id is set to avoid loading the City association (e.g. during seed).
  def generate_slug
    city_name = if self.class.column_names.include?("city_id") && city_id.present?
                  read_attribute(:city)
                else
                  respond_to?(:city) && city.respond_to?(:name) ? city&.name : read_attribute(:city)
                end
    base_slug = "#{read_attribute(:name)} #{city_name}".parameterize
    slug = base_slug
    counter = 1

    # Ensure uniqueness
    while Business.where(slug: slug).where.not(id: id).exists?
      slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    slug
  end

  class << self
    def h3_hex_indexes_for_radius(lat, lng, radius_km)
      origin = H3.from_geo_coordinates([lat, lng], H3_RESOLUTION)
      k = [(radius_km / H3_KM_PER_RING).ceil, 1].max
      H3.k_ring(origin, k).map { |i| i.to_s(16) }
    end
  end

  private

  def add_owner_as_staff
    return if user_id.blank?

    business_staff.find_or_create_by!(user_id: user_id) do |bs|
      bs.role = "owner"
      bs.active = true
    end
  end

  def sync_category_from_categories
    return unless self.class.column_names.include?("category")
    return if read_attribute(:category).present?

    raw = read_attribute(:categories)
    arr = raw.is_a?(Array) ? raw : []
    write_attribute(:category, arr.first.presence) if arr.any?
  end

  def generate_slug_if_needed
    return if read_attribute(:slug).to_s.start_with?("seed-")

    self.slug = generate_slug if slug.blank? || name_changed? || city_changed?
    self.slug_en = read_attribute(:slug) if slug_en.blank? && read_attribute(:slug).present?
  end

  def backfill_business_locales_from_canonical
    return unless self.class.column_names.include?("name_en")

    if read_attribute(:name).present? && name_en.blank? && name_fr.blank? && name_ar.blank?
      self.name_en = read_attribute(:name)
    end
    if read_attribute(:description).present? && description_en.blank? && description_fr.blank? && description_ar.blank?
      self.description_en = read_attribute(:description)
    end
    return unless read_attribute(:slug).present? && slug_en.blank? && slug_fr.blank? && slug_ar.blank?

    self.slug_en = read_attribute(:slug)
  end

  def sync_canonical_name_description_slug
    self[:name] = name_en.presence || name_fr.presence || name_ar.presence || read_attribute(:name)
    self[:description] =
      description_en.presence || description_fr.presence || description_ar.presence || read_attribute(:description)
    self[:slug] = slug_en.presence || slug_fr.presence || slug_ar.presence || read_attribute(:slug)
  end

  def set_h3_index_from_coordinates
    self.h3_index = if lat.present? && lng.present?
                      H3.from_geo_coordinates([lat.to_f, lng.to_f], H3_RESOLUTION).to_s(16)
                    end
  end

  def lat_or_lng_changed?
    lat_changed? || lng_changed?
  end

  def set_geo_validated_from_coordinates
    self.geo_validated = lat.present? && lng.present?
  end

  def enqueue_geocode_if_address_changed
    return if geocoding_address.blank?
    # Geocode when we have no coords, or when address parts changed (refresh)
    unless lat.blank? || lng.blank? || saved_change_to_address? || saved_change_to_city? || saved_change_to_country? || saved_change_to_neighborhood?
      return
    end

    BusinessGeocodeJob.perform_later(id)
  rescue StandardError => e
    Rails.logger.warn("[Business] Failed to enqueue BusinessGeocodeJob: #{e.message}")
  end

  def enqueue_search_index_update
    return unless defined?(RebuildBusinessSearchIndexJob)

    RebuildBusinessSearchIndexJob.perform_later(id)
  rescue StandardError => e
    Rails.logger.warn("[Business] Failed to enqueue RebuildBusinessSearchIndexJob: #{e.message}")
  end

  def onboarding_score_column?
    self.class.column_names.include?("onboarding_score")
  end

  def update_onboarding_score
    self.onboarding_score = compute_onboarding_score
  end

  def compute_onboarding_score
    has_services = services.kept.exists?
    has_cover_photos = logo.present? || (gallery_images || []).any?
    has_opening_hours = opening_hours.present? && opening_hours_values_any?
    has_staff = staff_members.exists?
    has_availability = staff_availabilities.exists?
    has_category = true
    has_geo = lat.present? && lng.present?
    [has_services, has_cover_photos, has_opening_hours, has_staff, has_availability, has_category, has_geo].count(true)
  end

  def opening_hours_values_any?
    return false unless opening_hours.is_a?(Hash)

    opening_hours.values.any? do |h|
      if h.is_a?(Array)
        h.any? { |int| int.is_a?(Hash) && (int["open"].present? || int[:open].present?) }
      else
        h.is_a?(Hash) && (h["open"].present? || h[:open].present?)
      end
    end
  end

  def normalize_opening_hours_to_arrays
    return if opening_hours.blank? || !opening_hours.is_a?(Hash)

    self.opening_hours = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
                          "sunday"].index_with do |day|
      raw = opening_hours[day] || opening_hours[day.to_sym]
      next [] if raw.blank?

      if raw.is_a?(Array)
        raw.filter_map do |h|
          next unless h.is_a?(Hash)

          open_val = h["open"].presence || h[:open].presence
          close_val = h["close"].presence || h[:close].presence
          { "open" => open_val.to_s, "close" => close_val.to_s } if open_val.present? && close_val.present?
        end
      else
        open_val = raw["open"].presence || raw[:open].presence
        close_val = raw["close"].presence || raw[:close].presence
        open_val.present? && close_val.present? ? [{ "open" => open_val.to_s, "close" => close_val.to_s }] : []
      end
    end
  end
end
