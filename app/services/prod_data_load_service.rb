# frozen_string_literal: true

# Runs the full prod_data load: cleanup seed users, ensure_canonical_acts!, load all JSON files, reset_categories.
# Used by rake prod_data:load (sync) and ProdDataLoadJob (Sidekiq). Yields progress messages to the block; if no block, uses Rails.logger.
class ProdDataLoadService
  class << self
    def call(canonical_act_translations: nil, &progress)
      @progress = progress || ->(msg) { Rails.logger.info "[ProdDataLoad] #{msg}" }
      @canonical_act_translations = canonical_act_translations || ProdDataLoadHelpers::CANONICAL_ACT_TRANSLATIONS
      run
    end

    private

    def log(msg)
      @progress.call(msg)
    end

    def run
      helper = Object.new.extend(ProdDataLoadHelpers)
      prod_data_dir = Pathname.new(ENV["PROD_DATA_DIR"].presence || Rails.root.join("prod_data"))
      batch_size = (ENV["PROD_DATA_BATCH_SIZE"] || 50).to_i
      discord_every = (ENV["DISCORD_PROGRESS_EVERY"] || 100).to_i
      skip_images = ENV["PROD_DATA_SKIP_IMAGES"] == "1"
      seed_password = ENV.fetch("SEED_PROVIDER_PASSWORD") { SecureRandom.hex(16) }

      unless File.directory?(prod_data_dir)
        log "❌ prod_data directory not found at #{prod_data_dir}"
        DiscordNotifier.notify("❌ **prod_data:load** failed: prod_data directory not found")
        return
      end

      unless User.table_exists? && Business.table_exists?
        log "❌ Required database tables are missing. Run: rails db:migrate"
        DiscordNotifier.notify("❌ **prod_data:load** failed: run db:migrate first")
        return
      end

      # Cleanup seed users and their businesses (and dependents: services, bookings, etc.)
      helper.ensure_connection!
      conditions = ProdDataLoadHelpers::PROD_DATA_SEED_EMAIL_DOMAINS.map { "email LIKE ?" }.join(" OR ")
      args = ProdDataLoadHelpers::PROD_DATA_SEED_EMAIL_DOMAINS.map { |d| "%#{d}" }
      seed_users = User.where(conditions, *args)
      seed_count = seed_users.count
      if seed_count.positive?
        business_count = Business.where(user_id: seed_users.select(:id)).count
        seed_users.find_each(&:destroy)
        log "🗑️  Cleared #{seed_count} seed provider user(s) and #{business_count} business(es) (and dependents) from previous run."
      end

      # Unlink services from categories we're about to remove so ensure_canonical_acts! won't hit FK
      if defined?(Category) && Category.table_exists? && defined?(Service) && Service.table_exists?
        ids_to_remove = Category.acts.where.not(name: Category::CANONICAL_NAMES).pluck(:id) + Category.subacts.pluck(:id)
        if ids_to_remove.any?
          Service.where(category_id: ids_to_remove).update_all(category_id: nil)
          log "   Unlinked services from #{ids_to_remove.size} non-canonical category/categories."
        end
      end

      log "📂 Loading prod data from #{prod_data_dir} (batch size: #{batch_size})"
      log "   ⚠️  PROD_DATA_SKIP_IMAGES=1 — Cloudinary uploads disabled" if skip_images

      if defined?(Category) && Category.table_exists?
        Category.ensure_canonical_acts!(@canonical_act_translations)
        log "   ✓ Canonical categories ensured."
      end

      json_files = Dir.glob(File.join(prod_data_dir, "*", "*", "*.json"))
      if json_files.empty?
        log "⚠️  No JSON files found under prod_data/*/*/*.json"
        DiscordNotifier.notify("⚠️ **prod_data:load** — no JSON files found")
        return
      end

      start_time = Time.current
      DiscordNotifier.notify("🚀 **prod_data:load** started (Sidekiq)\nFiles: #{json_files.size} | Batch: #{batch_size} | Env: #{Rails.env}")

      created_businesses = 0
      skipped = 0
      errors = []
      connection_retries = 0

      json_files.each_with_index do |path, file_idx|
        relative = Pathname.new(path).relative_path_from(prod_data_dir)
        parts = relative.each_filename.to_a
        if parts.size < 3
          log "⚠️  Skipping malformed path: #{path}"
          next
        end

        city_slug = parts[0].downcase
        category_slug = parts[1].downcase
        city_name = city_slug.titleize
        category_name = Category.canonical_name_for_slug(category_slug)

        helper.ensure_connection!

        if defined?(City) && City.table_exists?
          City.find_or_create_by!(slug: city_slug) do |c|
            c.name = city_name
            c.position = 0
          end
        end

        raw = File.read(path)
        items = begin
          JSON.parse(raw)
        rescue JSON::ParserError => e
          errors << "#{path}: #{e.message}"
          next
        end

        next unless items.is_a?(Array)

        log "   📄 [#{file_idx + 1}/#{json_files.size}] #{relative} (#{items.size} items)"

        used_slugs_in_file = Set.new
        pending_uploads = []

        items.each_slice(batch_size) do |batch|
          helper.ensure_connection!
          candidate_base_slugs = batch.filter_map do |item|
            title = item["title"].to_s.strip
            next if title.blank? || title.length < 2

            helper.normalize_slug(title, city_slug)
          end.compact.uniq
          existing_slugs = candidate_base_slugs.empty? ? Set.new : Business.where(slug: candidate_base_slugs).pluck(:slug).to_set

          batch.each do |item|
            title = item["title"].to_s.strip
            next if title.blank? || title.length < 2

            base_slug = helper.normalize_slug(title, city_slug)
            if base_slug.blank?
              skipped += 1
              next
            end
            if existing_slugs.include?(base_slug)
              skipped += 1
              next
            end

            slug = helper.generate_unique_slug(base_slug, used_slugs_in_file, existing_slugs)
            used_slugs_in_file << slug

            location = item["location"].to_s.strip.presence || helper.address_placeholder(city_name)
            phone = helper.normalize_phone(item["phone"].to_s)
            website = item["website"].to_s.strip
            website = nil if website.blank? || website == "N/A"
            description = item["description"].to_s.strip
            description = nil if description.blank? || description == "N/A"
            image_urls = helper.collect_image_urls(item)
            item_cat = item["category"].to_s.strip
            category_name_for_row = (if item_cat.present?
                                       Category.canonical_name_for_slug(item_cat.parameterize)
                                     end).presence || category_name
            email = helper.build_provider_email(slug)
            user_name = title.length >= 2 ? title[0..99] : "#{category_name_for_row} #{city_name}"

            row_attempts = 0
            begin
              row_attempts += 1
              helper.ensure_connection! if row_attempts > 1

              user = User.find_or_initialize_by(email: email)
              unless user.persisted?
                user.assign_attributes(
                  name: user_name,
                  password: seed_password,
                  password_confirmation: seed_password,
                  role: "provider",
                  provider_status: "confirmed"
                )
                user.phone = phone.presence if user.phone.blank?
                user.save!
              end

              business = Business.new(
                user_id: user.id,
                name: title[0..199],
                description: description,
                category: category_name_for_row,
                categories: [category_name_for_row],
                address: location[0..499],
                city: city_name,
                neighborhood: nil,
                phone: phone,
                email: email,
                website: website,
                slug: slug,
                verification_status: "verified",
                country: "Morocco"
              )
              business.published_at = Time.current
              business.geo_validated = false
              business.premium_expires_at = nil

              if business.save
                pending_uploads << [business, image_urls] if image_urls.any?
                created_businesses += 1

                if DiscordNotifier.webhook_url.present? && created_businesses.positive? && (created_businesses % discord_every).zero?
                  elapsed = (Time.current - start_time).to_i
                  DiscordNotifier.notify(
                    "📊 **prod_data** progress: **#{created_businesses}** created, #{skipped} skipped, #{errors.size} errors (#{elapsed}s elapsed)"
                  )
                end
              else
                errors << "#{title} (#{path}): #{business.errors.full_messages.join(', ')}"
              end
            rescue StandardError => e
              if helper.connection_error?(e) && row_attempts < 3
                connection_retries += 1
                sleep(row_attempts)
                retry
              end
              errors << "#{title} (#{path}): #{e.class} - #{e.message}"
            end
          end

          unless skip_images
            pending_uploads.each do |business, urls|
              helper.upload_business_images_to_cloudinary(business, urls)
            end
          end
          pending_uploads.clear
        end
      end

      elapsed = (Time.current - start_time).to_i
      log "✅ Done in #{elapsed}s. Created #{created_businesses} businesses, skipped #{skipped}."
      log "   Connection retries: #{connection_retries}" if connection_retries.positive?

      summary = "✅ **prod_data:load** finished in #{elapsed}s\nCreated: **#{created_businesses}** | Skipped: #{skipped} | Retries: #{connection_retries}"
      summary += "\n⚠️ Errors: #{errors.size}" if errors.any?
      DiscordNotifier.notify(summary)

      if errors.any?
        log "⚠️  Errors (#{errors.size}):"
        errors.first(20).each { |e| log "   - #{e}" }
        log "   ... and #{errors.size - 20} more" if errors.size > 20
        if DiscordNotifier.webhook_url.present?
          error_sample = errors.first(5).map { |e| "• #{e}" }.join("\n")
          DiscordNotifier.notify("🔴 **prod_data** error sample:\n#{error_sample}")
        end
      end

      ResetCategoriesFromBusinessesJob.perform_now
      log "✅ Categories reset."
    end
  end
end
