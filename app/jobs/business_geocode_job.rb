# frozen_string_literal: true

# Geocodes a business address to lat/lng and updates the record (triggers h3_index + geo_validated).
# Enqueued when address/city/country/neighborhood changes and lat/lng are missing or should be refreshed.
class BusinessGeocodeJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(business_id)
    business = Business.kept.find_by(id: business_id)
    return unless business

    address = business.geocoding_address
    return if address.blank?

    result = GeocodingService.geocode(address)
    return if result.blank?

    business.update(lat: result[:lat], lng: result[:lng])
  end
end
