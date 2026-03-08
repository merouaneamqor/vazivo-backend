# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Businesses", type: :request do
  let(:provider) { create(:user, :provider) }
  let(:customer) { create(:user, :customer) }
  let(:admin) { create(:user, :admin) }

  describe "GET /api/v1/businesses" do
    before do
      create_list(:business, 5, :with_services)
      create(:business, :discarded) # Soft-deleted, shouldn't appear
    end

    it "returns a paginated list of businesses" do
      get "/api/v1/businesses"

      expect(response).to have_http_status(:ok)
      expect(json_response[:businesses].length).to eq(5)
      expect(json_response[:meta][:total_count]).to eq(5)
    end

    it "filters by category" do
      create(:business, category: "Fitness")
      get "/api/v1/businesses", params: { category: "Fitness" }

      expect(response).to have_http_status(:ok)
      expect(json_response[:businesses].all? { |b| b[:category] == "Fitness" }).to be true
    end

    it "filters by city" do
      create(:business, city: "New York")
      get "/api/v1/businesses", params: { city: "New York" }

      expect(response).to have_http_status(:ok)
      expect(json_response[:businesses].all? { |b| b[:city] == "New York" }).to be true
    end

    it "searches by name" do
      create(:business, name: "Unique Spa Name")
      get "/api/v1/businesses", params: { q: "Unique Spa" }

      expect(response).to have_http_status(:ok)
      expect(json_response[:businesses].any? { |b| b[:name].include?("Unique Spa") }).to be true
    end
  end

  describe "GET /api/v1/businesses/:id" do
    let(:business) { create(:business, :with_services) }

    it "returns the business details" do
      get "/api/v1/businesses/#{business.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response[:business][:id]).to eq(business.id)
      expect(json_response[:business][:services]).to be_present
    end

    it "returns 404 for non-existent business" do
      get "/api/v1/businesses/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/businesses" do
    let(:valid_params) do
      {
        business: {
          name: "My Business",
          category: "Beauty & Wellness",
          address: "123 Main St",
          city: "New York",
          description: "A great place",
        },
      }
    end

    context "as a provider" do
      it "creates a new business" do
        expect do
          post "/api/v1/businesses", params: valid_params, headers: auth_headers_for(provider), as: :json
        end.to change(Business, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:business][:name]).to eq("My Business")
      end
    end

    context "as a customer" do
      it "returns forbidden" do
        post "/api/v1/businesses", params: valid_params, headers: auth_headers_for(customer), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        post "/api/v1/businesses", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/businesses/:id" do
    let(:business) { create(:business, user: provider) }

    context "as the owner" do
      it "updates the business" do
        patch "/api/v1/businesses/#{business.id}",
              params: { business: { name: "Updated Name" } },
              headers: auth_headers_for(provider),
              as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response[:business][:name]).to eq("Updated Name")
      end
    end

    context "as a different provider" do
      let(:other_provider) { create(:user, :provider) }

      it "returns forbidden" do
        patch "/api/v1/businesses/#{business.id}",
              params: { business: { name: "Hacked" } },
              headers: auth_headers_for(other_provider),
              as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      it "can update any business" do
        patch "/api/v1/businesses/#{business.id}",
              params: { business: { name: "Admin Updated" } },
              headers: auth_headers_for(admin),
              as: :json

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "DELETE /api/v1/businesses/:id" do
    let!(:business) { create(:business, user: provider) }

    context "as the owner" do
      it "soft-deletes the business" do
        expect do
          delete "/api/v1/businesses/#{business.id}", headers: auth_headers_for(provider)
        end.not_to change(Business, :count)

        expect(response).to have_http_status(:no_content)
        expect(business.reload.discarded?).to be true
      end
    end
  end
end
