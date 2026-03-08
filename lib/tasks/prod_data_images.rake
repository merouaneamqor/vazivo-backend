# frozen_string_literal: true

require "net/http"

# Enqueue Sidekiq jobs to upload images for businesses that have none.
# Scans the same prod_data JSON files as prod_data:load and finds businesses by canonical slug.
# Safe to run multiple times (idempotent: only enqueues when cover_image_url is blank).
#
# Run: bundle exec rake prod_data:enqueue_image_uploads
# Dry run: PROD_DATA_DRY_RUN=1 bundle exec rake prod_data:enqueue_image_uploads
#
# ENV: PROD_DATA_DIR (Rails.root/prod_data), PROD_DATA_DRY_RUN=1, DISCORD_WEBHOOK_URL
#
namespace :prod_data do
  PROD_DATA_DIR_IMAGES = (ENV["PROD_DATA_DIR"].presence || Rails.root.join("prod_data")).to_s.freeze
  DRY_RUN = ENV["PROD_DATA_DRY_RUN"] == "1"

  desc "Enqueue BusinessImageUploadJob for businesses missing logo/images in Active Storage (from prod_data JSON)"
  task enqueue_image_uploads: :environment do
    helper = Object.new.extend(ProdDataLoadHelpers)
    dir = Pathname.new(PROD_DATA_DIR_IMAGES)
    unless dir.directory?
      puts "❌ prod_data directory not found at #{dir}"
      exit 1
    end

    json_files = Dir.glob(File.join(dir, "*", "*", "*.json"))
    if json_files.empty?
      puts "⚠️  No JSON files found under #{dir}/*/*/*.json"
      exit 0
    end

    puts "📂 Scanning #{json_files.size} JSON files for businesses without logo/images"
    puts "   DRY RUN — no jobs will be enqueued" if DRY_RUN
    puts ""

    enqueued = 0
    skipped_no_images = 0
    skipped_has_images = 0
    not_found = 0

    json_files.each_with_index do |path, _file_idx|
      relative = Pathname.new(path).relative_path_from(dir)
      parts = relative.each_filename.to_a
      next if parts.size < 3

      city_slug = parts[0].downcase
      raw = File.read(path)
      items = JSON.parse(raw)
      next unless items.is_a?(Array)

      # Replay same slug assignment as prod_data:load: only used_slugs_in_file (no DB lookup),
      # so first row with base "a" gets "a", second gets "a-1", etc.
      used_slugs_in_file = Set.new

      items.each_slice(50) do |batch|
        batch.each do |item|
          title = item["title"].to_s.strip
          next if title.blank? || title.length < 2

          base_slug = helper.normalize_slug(title, city_slug)
          next if base_slug.blank?

          slug = helper.generate_unique_slug(base_slug, used_slugs_in_file, used_slugs_in_file)
          used_slugs_in_file << slug

          image_urls = helper.collect_image_urls(item)
          if image_urls.empty?
            skipped_no_images += 1
            next
          end

          business = Business.find_by(slug: slug)
          unless business
            not_found += 1
            next
          end

          if business.logo.attached? || business.images.attached?
            skipped_has_images += 1
            next
          end

          BusinessImageUploadJob.perform_later(business.id, image_urls) unless DRY_RUN
          enqueued += 1
        end
      end
    end

    puts "✅ Done."
    puts "   Enqueued: #{enqueued}"
    puts "   Skipped (no images in JSON): #{skipped_no_images}"
    puts "   Skipped (already has logo/images): #{skipped_has_images}"
    puts "   Not found in DB: #{not_found}"
    puts "   (dry run — no jobs enqueued)" if DRY_RUN

    if !DRY_RUN && enqueued.positive?
      DiscordNotifier.notify("📤 **prod_data:enqueue_image_uploads** finished — #{enqueued} jobs enqueued")
    end
  end
end
