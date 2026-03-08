# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Public::Businesses", type: :request do
  let!(:business1) do
    create(:business, :with_services, name: "Spa Oasis", category: "Beauty & Wellness", city: "Casablanca")
  end
  let!(:business2) { create(:business, :with_services, name: "Fitness Zone", category: "Fitness", city: "Rabat") }
  let!(:discarded_business) { create(:business, :discarded) }

  describe "GET /api/v1/public/businesses" do
    it "returns all active businesses" do
      get "/api/v1/public/businesses"

      expect(response).to have_http_status(:ok)
      expect(json_response[:businesses].length).to eq(2)
    end

    it "includes pagination meta" do
      get "/api/v1/public/businesses"

      expect(json_response[:meta]).to include(:current_page, :total_pages, :total_count)
    end

    context "with filters" do
      it "filters by category" do
        get "/api/v1/public/businesses", params: { category: "Fitness" }

        expect(json_response[:businesses].length).to eq(1)
        expect(json_response[:businesses].first[:name]).to eq("Fitness Zone")
      end

      it "filters by city" do
        get "/api/v1/public/businesses", params: { city: "Casablanca" }

        expect(json_response[:businesses].length).to eq(1)
        expect(json_response[:businesses].first[:name]).to eq("Spa Oasis")
      end
    end

    context "with sorting" do
      it "sorts by name" do
        get "/api/v1/public/businesses", params: { sort_by: "name" }

        expect(json_response[:businesses].first[:name]).to eq("Fitness Zone")
      end

      it "sorts by rating" do
        # Add reviews to business1
        service = business1.services.first
        user = create(:user, :customer)
        booking = create(:booking, :completed, service: service, business: business1, user: user)
        create(:review, booking: booking, business: business1, user: user, rating: 5)

        get "/api/v1/public/businesses", params: { sort_by: "rating" }

        expect(json_response[:businesses].first[:name]).to eq("Spa Oasis")
      end
    end
  end

  describe "GET /api/v1/public/businesses/search" do
    it "searches businesses by query" do
      get "/api/v1/public/businesses/search", params: { q: "spa" }

      expect(response).to have_http_status(:ok)
      expect(json_response[:businesses].length).to eq(1)
      expect(json_response[:businesses].first[:name]).to eq("Spa Oasis")
    end

    it "returns empty array when no matches" do
      get "/api/v1/public/businesses/search", params: { q: "nonexistent" }

      expect(response).to have_http_status(:ok)
      expect(json_response[:businesses]).to be_empty
    end

    context "with lat, lng, and radius (H3 location filter)" do
      it "returns businesses within radius of the center" do
        # business1 is in Casablanca (factory uses Faker lat/lng; ensure known coords)
        business1.update!(lat: 33.5, lng: -7.5)
        business2.update!(lat: 48.8, lng: 2.3) # Paris

        get "/api/v1/public/businesses/search", params: { lat: 33.5, lng: -7.5, radius: 10 }

        expect(response).to have_http_status(:ok)
        names = json_response[:businesses].pluck(:name)
        expect(names).to include("Spa Oasis")
        expect(names).not_to include("Fitness Zone")
      end
    end
  end

  describe "GET /api/v1/public/businesses/nearby" do
    it "returns businesses near the given lat/lng (H3-based)" do
      business1.update!(lat: 33.5, lng: -7.5)
      business2.update!(lat: 48.8, lng: 2.3)

      get "/api/v1/public/businesses/nearby", params: { lat: 33.5, lng: -7.5, radius: 10 }

      expect(response).to have_http_status(:ok)
      names = json_response[:businesses].pluck(:name)
      expect(names).to include("Spa Oasis")
      expect(names).not_to include("Fitness Zone")
    end

    it "returns 400 when location is missing" do
      get "/api/v1/public/businesses/nearby"

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "GET /api/v1/public/businesses/featured" do
    it "returns featured businesses" do
      get "/api/v1/public/businesses/featured"

      expect(response).to have_http_status(:ok)
      expect(json_response[:businesses]).to be_an(Array)
    end

    it "respects limit parameter" do
      get "/api/v1/public/businesses/featured", params: { limit: 1 }

      expect(json_response[:businesses].length).to be <= 1
    end
  end

  describe "GET /api/v1/public/businesses/:slug" do
    it "returns business by slug" do
      get "/api/v1/public/businesses/#{business1.slug}"

      expect(response).to have_http_status(:ok)
      expect(json_response[:business][:name]).to eq("Spa Oasis")
      expect(json_response[:business][:slug]).to eq(business1.slug)
    end

    it "includes services and reviews" do
      get "/api/v1/public/businesses/#{business1.slug}"

      expect(json_response[:business][:services]).to be_an(Array)
      expect(json_response[:business][:reviews]).to be_an(Array)
    end

    it "returns 404 for non-existent business" do
      get "/api/v1/public/businesses/non-existent-slug"

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for discarded business" do
      get "/api/v1/public/businesses/#{discarded_business.slug}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/public/businesses/:slug/services" do
    it "returns services for a business" do
      get "/api/v1/public/businesses/#{business1.slug}/services"

      expect(response).to have_http_status(:ok)
      expect(json_response[:services]).to be_an(Array)
      expect(json_response[:services].length).to eq(business1.services.kept.count)
    end
  end

  describe "GET /api/v1/public/businesses/:slug/reviews" do
    let(:service) { business1.services.first }
    let(:user) { create(:user, :customer) }
    let!(:booking) { create(:booking, :completed, service: service, business: business1, user: user) }
    let!(:review) do
      create(:review, booking: booking, business: business1, user: user, rating: 5, comment: "Excellent!")
    end

    it "returns reviews for a business" do
      get "/api/v1/public/businesses/#{business1.slug}/reviews"

      expect(response).to have_http_status(:ok)
      expect(json_response[:reviews]).to be_an(Array)
      expect(json_response[:reviews].first[:rating]).to eq(5)
    end

    it "includes pagination meta" do
      get "/api/v1/public/businesses/#{business1.slug}/reviews"

      expect(json_response[:meta]).to include(:current_page, :total_pages, :total_count)
    end
  end
end
