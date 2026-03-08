# frozen_string_literal: true

# Geocodes an address string to latitude/longitude using the free Nominatim API (OpenStreetMap).
# No API key required. Usage policy: https://operations.osmfoundation.org/policies/nominatim/
# (1 request/second for bulk; set GEOCODING_USER_AGENT to identify your app.)
class GeocodingService
  NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
  DEFAULT_USER_AGENT = "OllaZenBooking/1.0 (booking@ollazen.ma)"

  # @param address [String] full address (e.g. "123 Main St, Casablanca, Morocco")
  # @return [Hash] { lat: Float, lng: Float } or {} if not found / error
  def self.geocode(address)
    return {} if address.blank?

    address = address.to_s.strip
    return {} if address.empty?

    geocode_nominatim(address)
  end

  # Free Nominatim (OSM) geocoding. User-Agent required by usage policy.
  def self.geocode_nominatim(address)
    res = HTTParty.get(
      NOMINATIM_URL,
      query: { q: address, format: "json", limit: 1 },
      headers: { "User-Agent" => ENV.fetch("GEOCODING_USER_AGENT", DEFAULT_USER_AGENT) },
      timeout: 5
    )
    return {} unless res.success?

    data = res.parsed_response
    return {} unless data.is_a?(Array) && data.first.is_a?(Hash)

    first = data.first
    lat = first["lat"]&.to_f
    lng = first["lon"]&.to_f
    return {} unless lat && lng

    { lat: lat, lng: lng }
  rescue StandardError => e
    Rails.logger.warn("[GeocodingService] Nominatim geocode failed: #{e.message}")
    {}
  end
end
