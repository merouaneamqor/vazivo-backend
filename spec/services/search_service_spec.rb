# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchService do
  describe "#search_businesses" do
    let!(:business_near) { create(:business, name: "Near Spa", lat: 33.5, lng: -7.5, city: "Casablanca") }
    let!(:business_far) { create(:business, name: "Far Spa", lat: 48.8, lng: 2.3, city: "Paris") }

    context "with lat, lng, and radius (H3 location filter)" do
      it "returns businesses within H3 radius of the center" do
        service = described_class.new(lat: 33.5, lng: -7.5, radius: 10)
        scope = service.search_businesses

        expect(scope).to include(business_near)
        expect(scope).not_to include(business_far)
      end

      it "uses default radius when radius not provided" do
        service = described_class.new(lat: 33.5, lng: -7.5)
        scope = service.search_businesses

        expect(scope).to include(business_near)
      end

      it "returns no businesses when center has no businesses in H3 cells" do
        # Center in ocean / remote area with no businesses
        service = described_class.new(lat: 0, lng: 0, radius: 5)
        scope = service.search_businesses

        expect(scope).not_to include(business_near, business_far)
      end
    end

    context "without lat/lng" do
      it "does not apply location filter" do
        service = described_class.new(city: "Casablanca")
        scope = service.search_businesses

        expect(scope).to include(business_near)
        expect(scope).not_to include(business_far)
      end
    end

    context "with nil lat or lng" do
      it "does not apply location filter when only lat is present" do
        service = described_class.new(lat: 33.5, city: "Casablanca")
        scope = service.search_businesses

        expect(scope).to include(business_near)
      end

      it "does not apply location filter when only lng is present" do
        service = described_class.new(lng: -7.5, city: "Casablanca")
        scope = service.search_businesses

        expect(scope).to include(business_near)
      end
    end
  end
end
