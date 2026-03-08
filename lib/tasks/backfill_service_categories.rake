# frozen_string_literal: true

namespace :backfill do
  desc "Backfill service_category_id for existing services by creating/using an 'Uncategorized' service category per business"
  task service_categories: :environment do
    puts "Backfilling service categories for existing services..."

    Business.kept.includes(:services, :service_categories).find_each do |business|
      uncategorized = business.service_categories.where("LOWER(name) = ?", "uncategorized").first

      if uncategorized.nil?
        uncategorized = business.service_categories.create!(
          name: "Uncategorized",
          color: "#6B7280", # neutral gray
          position: (business.service_categories.maximum(:position) || 0) + 1
        )
        puts "Created 'Uncategorized' category for business ##{business.id} (#{business.name})"
      end

      scope = business.services.kept.where(service_category_id: nil)
      count = scope.count
      next if count.zero?

      scope.find_each do |service|
        service.update_columns(service_category_id: uncategorized.id, updated_at: Time.current)
      end

      puts "  Assigned #{count} service(s) to 'Uncategorized' for business ##{business.id}"
    end

    puts "Backfill complete."
  end
end

