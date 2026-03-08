# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::SearchMetadata", type: :request do
  let!(:business1) { create(:business, category: "Beauty & Wellness", city: "Casablanca") }
  let!(:business2) { create(:business, category: "Fitness", city: "Rabat") }
  let!(:business3) { create(:business, category: "Beauty & Wellness", city: "Casablanca") }
  let!(:service1) { create(:service, business: business1, price: 50) }
  let!(:service2) { create(:service, business: business2, price: 200) }

  describe "GET /api/v1/search_metadata/cities" do
    it "returns list of cities with business counts" do
      get "/api/v1/search_metadata/cities"

      expect(response).to have_http_status(:ok)
      expect(json_response[:cities]).to be_an(Array)

      casablanca = json_response[:cities].find { |c| c[:name] == "Casablanca" }
      expect(casablanca).to be_present
      expect(casablanca[:business_count]).to eq(2)
    end

    it "excludes cities with discarded businesses only" do
      create(:business, :discarded, city: "Ghost City")

      get "/api/v1/search_metadata/cities"

      ghost_city = json_response[:cities].find { |c| c[:name] == "Ghost City" }
      expect(ghost_city).to be_nil
    end
  end

  describe "GET /api/v1/search_metadata/categories" do
    it "returns list of categories with business counts" do
      get "/api/v1/search_metadata/categories"

      expect(response).to have_http_status(:ok)
      expect(json_response[:categories]).to be_an(Array)

      beauty = json_response[:categories].find { |c| c[:name] == "Beauty & Wellness" }
      expect(beauty).to be_present
      expect(beauty[:business_count]).to eq(2)
    end
  end

  describe "GET /api/v1/search_metadata/filters" do
    it "returns cities, categories, and price range" do
      get "/api/v1/search_metadata/filters"

      expect(response).to have_http_status(:ok)
      expect(json_response[:cities]).to be_an(Array)
      expect(json_response[:categories]).to be_an(Array)
      expect(json_response[:price_range]).to include(:min, :max)
      expect(json_response[:price_range][:min]).to eq(50)
      expect(json_response[:price_range][:max]).to eq(200)
    end
  end
end
