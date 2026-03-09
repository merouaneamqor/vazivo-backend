# frozen_string_literal: true

# One-time migration: copy business cover_image_url / gallery_urls into Active Storage (logo + images),
# then clear those columns. Run before removing the DB columns.
#
# Run: bundle exec rake business_images:migrate_to_active_storage
# Dry run: DRY_RUN=1 bundle exec rake business_images:migrate_to_active_storage
#
namespace :business_images do
  desc "Migrate business cover_image_url and gallery_urls into Active Storage (logo + images), then clear columns"
  task migrate_to_active_storage: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    puts "Migrating business image columns to Active Storage..."
    puts "DRY RUN — no changes will be saved" if dry_run

    unless Business.column_names.include?("cover_image_url") || Business.column_names.include?("gallery_urls")
      puts "Columns cover_image_url / gallery_urls not present; nothing to migrate."
      exit 0
    end

    helper = Object.new.extend(ProdDataLoadHelpers)
    migrated = 0
    skipped = 0
    errors = 0

    Business.find_each do |business|
      cover = business.read_attribute(:cover_image_url)
      gallery = business.read_attribute(:gallery_urls)
      gallery = Array(gallery).compact_blank if gallery.present?

      next if cover.blank? && gallery.blank?

      if business.logo.attached? || business.images.attached?
        skipped += 1
        next
      end

      urls = [cover, *gallery].compact_blank.uniq
      next if urls.empty?

      if dry_run
        migrated += 1
      else
        begin
          helper.attach_business_images_from_urls(business, urls)
          updates = {}
          updates[:cover_image_url] = nil if Business.column_names.include?("cover_image_url")
          updates[:gallery_urls] = [] if Business.column_names.include?("gallery_urls")
          updates[:logo_url] = nil if Business.column_names.include?("logo_url")
          business.update_columns(updates) if updates.any?
          migrated += 1
        rescue StandardError => e
          errors += 1
          Rails.logger.error "[business_images:migrate_to_active_storage] Business #{business.id}: #{e.message}"
        end
      end
    end

    puts "Done. Migrated: #{migrated}, Skipped (already have AS): #{skipped}, Errors: #{errors}"
  end
end
