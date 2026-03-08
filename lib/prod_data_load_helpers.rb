# frozen_string_literal: true

require "timeout"
require "open-uri"

# Shared utilities for the production data pipeline (rake prod_data:load and BusinessImageUploadJob).
# Slug is the canonical identity for a business; all operations are idempotent.
module ProdDataLoadHelpers
  # Email domains for prod_data/seed users. Used by build_provider_email (first), cleanup, and mail interceptor.
  PROD_DATA_SEED_EMAIL_DOMAINS = ["@seed.ollazen.ma", "@seed.glow.ma"].freeze
  PROD_DATA_SEED_EMAIL_DOMAIN = PROD_DATA_SEED_EMAIL_DOMAINS.first

  # Database translations for the 5 canonical Category acts (en/fr/ar + slug). Keep in sync with prod_data.rake.
  # Used by ProdDataLoadService when run from Sidekiq (rake passes its own constant).
  CANONICAL_ACT_TRANSLATIONS = [
    { en: "Salon de Beauté",  fr: "Salon de Beauté",  ar: "صالون تجميل",  slug: "salon-de-beaute" },
    { en: "Barber",           fr: "Barber",           ar: "حلاق رجال",    slug: "barber" },
    { en: "Hammam",           fr: "Hammam",           ar: "حمام",         slug: "hammam" },
    { en: "Massage & Spa",    fr: "Massage & Spa",    ar: "مساج وسبا",    slug: "massage-spa" },
    { en: "Nail Salon",       fr: "Institut Ongles",  ar: "صالون أظافر", slug: "nail-salon" },
  ].freeze

  def self.seed_email?(email)
    return false if email.blank?

    normalized = email.to_s.strip.downcase
    PROD_DATA_SEED_EMAIL_DOMAINS.any? { |d| normalized.end_with?(d.downcase) }
  end

  # Returns a slug of max 250 chars. Parameterize once, then truncate so stored slug matches.
  def normalize_slug(title, city_slug)
    base = "#{title.to_s.strip}-#{city_slug}".parameterize.presence
    return nil if base.blank?

    base[0..249]
  end

  def generate_unique_slug(base, used_slugs, existing_slugs)
    slug = base
    n = 1
    while used_slugs.include?(slug) || existing_slugs.include?(slug)
      slug = "#{base}-#{n}"
      slug = slug[0..249]
      n += 1
    end
    slug
  end

  def normalize_phone(str)
    return nil if str.blank? || str == "N/A"

    str.gsub(/\s+/, " ").strip
  end

  def address_placeholder(city_name)
    "#{city_name}, Morocco"
  end

  # Merge images + image keys and dedupe. Both may be present; don't lose single image.
  def collect_image_urls(item)
    from_images = Array(item["images"]).map { |u| u.to_s.strip }.compact_blank
    from_single = item["image"].to_s.strip.presence
    (from_images + (from_single ? [from_single] : [])).uniq
  end

  # Build email so it never truncates mid-domain. Local part capped so full string fits.
  def build_provider_email(slug)
    local = "prod+#{slug.parameterize[0..230]}"
    "#{local}#{PROD_DATA_SEED_EMAIL_DOMAIN}"
  end

  # Verify or re-establish DB connection. Safe to call frequently.
  def ensure_connection!
    ActiveRecord::Base.connection.verify!
  rescue StandardError
    begin
      ActiveRecord::Base.connection.reconnect!
    rescue StandardError
      ActiveRecord::Base.connection_pool.disconnect!
      ActiveRecord::Base.establish_connection
    end
  end

  # Returns true if rescue-worthy PG/AR connection error
  def connection_error?(exception)
    exception.is_a?(PG::ConnectionBad) ||
      exception.is_a?(PG::UnableToSend) ||
      exception.is_a?(ActiveRecord::ConnectionNotEstablished) ||
      exception.is_a?(ActiveRecord::ConnectionFailed)
  end

  UPLOAD_TIMEOUT_SEC = (ENV["PROD_DATA_UPLOAD_TIMEOUT"] || 45).to_i

  # Uploads image URLs to Cloudinary, then attaches the resulting URLs to the business
  # via Active Storage (logo = first, images = all). Single source of truth is Active Storage.
  def upload_business_images_to_cloudinary(business, urls)
    return { cover_url: nil, gallery_urls: [] } if urls.blank?

    unless defined?(Cloudinary) && Cloudinary.config.api_key.present?
      Rails.logger.warn "[ProdDataLoadHelpers] Cloudinary not configured (set CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET on the Sidekiq worker)"
      return { cover_url: nil, gallery_urls: [] }
    end

    folder_gallery = CloudinaryPathBuilder.business_gallery_folder(business.id)
    uploaded = urls.filter_map do |url|
      next if url.blank?
      next if url.to_s.include?("res.cloudinary.com")

      Timeout.timeout(UPLOAD_TIMEOUT_SEC) do
        result = CloudinaryUploader.upload(url, folder: folder_gallery)
        result&.dig(:secure_url)
      end
    rescue Timeout::Error
      warn "  [skip] image not responding (timeout): #{url[0..80]}..."
      nil
    rescue StandardError => e
      warn "  [skip] image failed (#{e.class}: #{e.message[0..60]}): #{url[0..60]}..."
      nil
    end
    return { cover_url: nil, gallery_urls: [] } if uploaded.empty?

    cover = uploaded.first
    2.times do |attempt|
      ensure_connection!
      attach_business_images_from_urls(business, uploaded)
      break
    rescue StandardError => e
      break unless connection_error?(e) && attempt.zero?
    end
    { cover_url: cover, gallery_urls: uploaded }
  end

  # Downloads URLs and attaches to business: first URL -> logo, all URLs -> images (CarrierWave).
  def attach_business_images_from_urls(business, gallery_urls)
    urls = Array(gallery_urls).compact_blank
    return if urls.empty?

    # Set logo from first URL
    business.remote_logo_url = urls.first
    
    # Add all URLs to gallery
    urls.each do |url|
      public_id = url.match(/\/v\d+\/(.+?)(?:\.[^.]+)?$/)[1] rescue SecureRandom.uuid
      business.add_gallery_image(url, public_id)
    end
    
    business.save
  end

  # Attach a single URL as the business logo only (used when controller uploads logo to Cloudinary first).
  def attach_logo_from_url(business, url)
    return if url.blank?

    business.remote_logo_url = url
    business.save
  end

  # Attach URLs as gallery images only; does not touch logo (used when controller uploads images to Cloudinary first).
  def attach_images_from_urls(business, urls)
    urls = Array(urls).compact_blank
    return if urls.empty?

    urls.each do |url|
      public_id = url.match(/\/v\d+\/(.+?)(?:\.[^.]+)?$/)[1] rescue SecureRandom.uuid
      business.add_gallery_image(url, public_id)
    end
  end

  def attach_remote_url(business, url, attach_as_logo: false, attach_as_image: false)
    if attach_as_logo
      business.remote_logo_url = url
      business.save
    end
    
    if attach_as_image
      public_id = url.match(/\/v\d+\/(.+?)(?:\.[^.]+)?$/)[1] rescue SecureRandom.uuid
      business.add_gallery_image(url, public_id)
    end
  rescue StandardError => e
    Rails.logger.warn "[ProdDataLoadHelpers] attach_remote_url failed #{url[0..80]}: #{e.message}"
  end
end
