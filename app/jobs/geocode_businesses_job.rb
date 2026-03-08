# frozen_string_literal: true

# Periodic job to geocode businesses that have addresses but no coordinates.
# Runs via Sidekiq scheduler to batch-process businesses missing lat/lng.
class GeocodeBusinessesJob < ApplicationJob
  queue_as :default

  def perform(batch_size: 50)
    businesses = Business.kept
      .where(lat: nil)
      .or(Business.kept.where(lng: nil))
      .where.not(address: [nil, ""])
      .limit(batch_size)

    businesses.find_each do |business|
      BusinessGeocodeJob.perform_later(business.id)
      sleep(1) # Respect Nominatim rate limit (1 req/sec)
    end

    Rails.logger.info("[GeocodeBusinessesJob] Enqueued #{businesses.count} businesses for geocoding")
  end
end
