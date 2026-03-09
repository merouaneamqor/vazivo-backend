# frozen_string_literal: true

# Loads production data from a single TripAdvisor-shaped JSON file (prod_data/seed_file.json).
#
# Seed file format: JSON array of restaurant objects. Each item has:
#   name, rating, numberOfReviews, address, addressObj{ street1, street2, city, country },
#   ancestorLocations [ { name, subcategory } ], latitude, longitude, cuisines[], phone, website,
#   image (single URL), images (array of URLs)
#
# Creates City (bypassing Mobility via bracket notation), User (provider), and Business per row.
# Uses RestaurantImport::CuisineMapper for category; idempotent by slug.
#
# ENV: PROD_DATA_SEED_FILE_PATH, PROD_DATA_SKIP_IMAGES, PROD_DATA_BATCH_SIZE,
#      SEED_PROVIDER_PASSWORD, DISCORD_WEBHOOK_URL, DISCORD_PROGRESS_EVERY
#
class ProdDataSeedFileLoadService
  class << self
    def call(seed_file_path: nil, skip_images: nil, batch_size: nil, seed_password: nil, cleanup_seed_users: false,
             &progress)
      @progress = progress || ->(msg) { Rails.logger.info "[ProdDataSeedFileLoad] #{msg}" }
      @seed_file_path = Pathname.new(seed_file_path.presence || ENV["PROD_DATA_SEED_FILE_PATH"].presence || Rails.root.join(
        "prod_data", "seed_file.json"
      ))
      @skip_images = skip_images.nil? ? ENV["PROD_DATA_SKIP_IMAGES"] == "1" : skip_images
      @batch_size = (batch_size || ENV["PROD_DATA_BATCH_SIZE"] || 50).to_i
      @seed_password = seed_password.presence || ENV.fetch("SEED_PROVIDER_PASSWORD") { SecureRandom.hex(16) }
      @discord_every = (ENV["DISCORD_PROGRESS_EVERY"] || 100).to_i
      @cleanup_seed_users = cleanup_seed_users
      run
    end

    private

    def log(msg)
      @progress.call(msg)
    end

    def run
      helper = Object.new.extend(ProdDataLoadHelpers)

      unless @seed_file_path.file?
        log "❌ Seed file not found at #{@seed_file_path}"
        if defined?(DiscordNotifier)
          DiscordNotifier.notify("❌ **prod_data:load_seed_file** failed: file not found at #{@seed_file_path}")
        end
        return
      end

      unless User.table_exists? && Business.table_exists?
        log "❌ Required database tables are missing. Run: rails db:migrate"
        if defined?(DiscordNotifier)
          DiscordNotifier.notify("❌ **prod_data:load_seed_file** failed: run db:migrate first")
        end
        return
      end

      cleanup_seed_users!(helper) if @cleanup_seed_users

      if defined?(Category) && Category.table_exists?
        Category.ensure_canonical_acts!(nil)
        log "   ✓ Canonical cuisine categories ensured."
      end

      raw = File.read(@seed_file_path)
      items = JSON.parse(raw)
      unless items.is_a?(Array)
        log "❌ JSON root must be an array"
        return
      end

      log "📂 Loading from #{@seed_file_path} (batch size: #{@batch_size})"
      log "   ⚠️  PROD_DATA_SKIP_IMAGES=1 — Cloudinary uploads disabled" if @skip_images

      if defined?(DiscordNotifier) && DiscordNotifier.webhook_url.present?
        DiscordNotifier.notify("🚀 **prod_data:load_seed_file** started\nItems: #{items.size} | Batch: #{@batch_size} | Env: #{Rails.env}")
      end

      start_time = Time.current
      created_businesses = 0
      skipped = 0
      errors = []
      connection_retries = 0
      used_slugs = Set.new
      pending_uploads = []

      items.each_slice(@batch_size) do |batch|
        helper.ensure_connection!

        existing_slugs = batch_existing_slugs(batch, helper)
        batch.each do |item|
          result = process_item(item, helper, used_slugs, existing_slugs, pending_uploads, errors)
          case result
          when :created
            created_businesses += 1
            if defined?(DiscordNotifier) && DiscordNotifier.webhook_url.present? && created_businesses.positive? && (created_businesses % @discord_every).zero?
              elapsed = (Time.current - start_time).to_i
              DiscordNotifier.notify("📊 **prod_data:load_seed_file** progress: **#{created_businesses}** created, #{skipped} skipped, #{errors.size} errors (#{elapsed}s elapsed)")
            end
          when :skipped then skipped += 1
          when :error # already appended to errors
          end
        end

        flush_image_uploads!(helper, pending_uploads) unless @skip_images
      end

      finish_run(helper, start_time, created_businesses, skipped, connection_retries, errors)
    end

    def cleanup_seed_users!(helper)
      helper.ensure_connection!
      conditions = ProdDataLoadHelpers::PROD_DATA_SEED_EMAIL_DOMAINS.map { "email LIKE ?" }.join(" OR ")
      args = ProdDataLoadHelpers::PROD_DATA_SEED_EMAIL_DOMAINS.map { |d| "%#{d}" }
      seed_users = User.where(conditions, *args)
      seed_count = seed_users.count
      return if seed_count.zero?

      business_count = Business.where(user_id: seed_users.select(:id)).count
      seed_users.find_each(&:destroy)
      log "🗑️  Cleared #{seed_count} seed provider user(s) and #{business_count} business(es) from previous run."
    end

    def batch_existing_slugs(batch, helper)
      candidate_slugs = batch.filter_map do |item|
        name = item["name"].to_s.strip
        city_name = city_name_from_item(item)
        next if name.blank? || name.length < 2 || city_name.blank?

        helper.normalize_slug(name, city_name.parameterize)
      end.compact.uniq
      candidate_slugs.empty? ? Set.new : Business.where(slug: candidate_slugs).pluck(:slug).to_set
    end

    def process_item(item, helper, used_slugs, existing_slugs, pending_uploads, errors)
      name = item["name"].to_s.strip
      return :skipped if name.blank? || name.length < 2

      city_name = city_name_from_item(item)
      return :skipped if city_name.blank?

      city_slug = city_name.to_s.parameterize.presence || "city"
      base_slug = helper.normalize_slug(name, city_slug)
      return :skipped if base_slug.blank?
      return :skipped if existing_slugs.include?(base_slug)

      slug = helper.generate_unique_slug(base_slug, used_slugs, existing_slugs)
      used_slugs << slug
      existing_slugs << slug

      name_val = name[0..199]
      slug_val = slug.to_s

      row_attempts = 0
      begin
        row_attempts += 1
        helper.ensure_connection! if row_attempts > 1

        city = find_or_create_city(city_name, city_slug)
        email = helper.build_provider_email(slug)
        user = find_or_create_provider_user(email, name[0..99], helper.normalize_phone(item["phone"].to_s), helper)

        business = build_business(item, user.id, city, city_name, slug_val, name_val, helper)
        if business.save
          image_urls = helper.collect_image_urls(item)
          pending_uploads << [business, image_urls] if image_urls.any?
          return :created
        end

        errors << "#{name}: #{business.errors.full_messages.join(', ')}"
        :error
      rescue StandardError => e
        if helper.connection_error?(e) && row_attempts < 3
          sleep(row_attempts)
          retry
        end
        errors << "#{name}: #{e.class} - #{e.message}"
        :error
      end
    end

    def find_or_create_city(city_name, city_slug)
      return nil unless defined?(City) && City.table_exists?

      name_str = city_name.to_s.strip
      base_slug = city_slug.to_s.parameterize.presence || "city"

      existing = City.where("LOWER(name) = ?", name_str.downcase).first if name_str.present?
      existing ||= City.find_by(slug: base_slug)
      return existing if existing

      slug = base_slug
      n = 1
      while City.exists?(slug: slug)
        slug = "#{base_slug}-#{n}"
        n += 1
      end

      final_name = name_str.presence || city_name.to_s
      city = City.new
      city[:name]    = final_name
      city[:slug]    = slug
      city[:name_en] = final_name
      city[:slug_en] = slug
      city.position  = 0
      city.save!
      city
    end

    def find_or_create_provider_user(email, user_name, phone, _helper)
      user = User.find_or_initialize_by(email: email)
      return user if user.persisted?

      user.assign_attributes(
        name: user_name,
        password: @seed_password,
        password_confirmation: @seed_password,
        role: "provider",
        provider_status: "confirmed"
      )
      user.phone = phone.presence if user.phone.blank?
      user.save!
      user
    end

    def build_business(item, user_id, city, city_name, slug_val, name_val, helper)
      category_name = RestaurantImport::CuisineMapper.to_canonical(item["cuisines"])
      address = address_from_item(item, city_name)
      phone = helper.normalize_phone(item["phone"].to_s)
      website = item["website"].to_s.strip.presence
      website = nil if website.blank? || website == "N/A"
      email = helper.build_provider_email(slug_val)

      business = Business.new(
        user_id: user_id,
        description: nil,
        category: category_name,
        categories: [category_name],
        address: address[0..499],
        city: city_name,
        city_id: city&.id,
        neighborhood: nil,
        phone: phone,
        email: email,
        website: website,
        verification_status: "verified",
        country: "Morocco",
        lat: item["latitude"],
        lng: item["longitude"]
      )

      # Bypass Mobility: set canonical and default locale columns directly so validations pass
      business[:name]    = name_val
      business[:slug]    = slug_val
      business[:name_en] = name_val
      business[:slug_en] = slug_val

      business.published_at = Time.current
      business.geo_validated = business.lat.present? && business.lng.present?
      business.premium_expires_at = nil

      if business.respond_to?(:average_rating=)
        rating = item["rating"]
        business.average_rating = rating.is_a?(Numeric) ? rating.to_f : 0.0
      end
      if business.respond_to?(:reviews_count=)
        count = item["numberOfReviews"]
        business.reviews_count = if count.is_a?(Integer)
                                   count
                                 else
                                   begin
                                     count.to_i
                                   rescue StandardError
                                     0
                                   end
                                 end
      end

      business
    end

    def flush_image_uploads!(helper, pending_uploads)
      pending_uploads.each do |business, urls|
        helper.upload_business_images_to_cloudinary(business, urls) if urls.any?
      end
      pending_uploads.clear
    end

    def finish_run(_helper, start_time, created_businesses, skipped, connection_retries, errors)
      elapsed = (Time.current - start_time).to_i
      log "✅ Done in #{elapsed}s. Created #{created_businesses} businesses, skipped #{skipped}."
      log "   Connection retries: #{connection_retries}" if connection_retries.positive?

      summary = "✅ **prod_data:load_seed_file** finished in #{elapsed}s\nCreated: **#{created_businesses}** | Skipped: #{skipped} | Retries: #{connection_retries}"
      summary += "\n⚠️ Errors: #{errors.size}" if errors.any?
      DiscordNotifier.notify(summary) if defined?(DiscordNotifier) && DiscordNotifier.webhook_url.present?

      if errors.any?
        log "⚠️  Errors (#{errors.size}):"
        errors.first(20).each { |e| log "   - #{e}" }
        log "   ... and #{errors.size - 20} more" if errors.size > 20
      end

      return unless defined?(ResetCategoriesFromBusinessesJob)

      ResetCategoriesFromBusinessesJob.perform_now
      log "✅ Categories reset."
    end

    # ——— Seed file field extraction (TripAdvisor-shaped JSON) ———

    def city_name_from_item(item)
      addr = item["addressObj"]
      return addr["city"].to_s.strip if addr.is_a?(Hash) && addr["city"].to_s.strip.present?

      ancestors = item["ancestorLocations"]
      return nil unless ancestors.is_a?(Array)

      ville = ancestors.find { |a| a.is_a?(Hash) && a["subcategory"].to_s.strip.downcase == "ville" }
      ville && ville["name"].to_s.strip.presence
    end

    def address_from_item(item, city_name)
      addr = item["address"].to_s.strip.presence
      return addr if addr.present?

      obj = item["addressObj"]
      if obj.is_a?(Hash)
        parts = [obj["street1"].to_s.strip, obj["street2"].to_s.strip].compact_blank
        return parts.join(", ") if parts.any?
      end
      "#{city_name}, Morocco"
    end
  end
end
