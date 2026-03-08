# frozen_string_literal: true

# Enqueue BusinessGeocodeJob for businesses missing lat/lng.
# Usage: bundle exec rake businesses:geocode_missing
# Optional: DELAY_SECONDS=1 (space between enqueues, for Nominatim 1 req/sec)
namespace :businesses do
  desc "Enqueue geocode jobs for businesses with address but missing lat/lng"
  task geocode_missing: :environment do
    delay_sec = (ENV["DELAY_SECONDS"] || "0").to_f

    scope = Business.kept.where("(lat IS NULL OR lng IS NULL) AND address IS NOT NULL AND address != ''")
    ids = scope.pluck(:id)
    total = ids.size

    if total.zero?
      puts "No businesses missing coordinates."
      next
    end

    puts "Enqueueing BusinessGeocodeJob for #{total} business(es) missing coordinates..."
    ids.each_with_index do |business_id, i|
      wait = delay_sec.positive? ? (i * delay_sec).seconds : 0
      BusinessGeocodeJob.set(wait: wait).perform_later(business_id)
    end
    puts "Done. #{total} job(s) enqueued."
  end
end
