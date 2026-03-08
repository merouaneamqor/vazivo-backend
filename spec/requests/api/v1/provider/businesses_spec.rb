# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Provider::Businesses", type: :request do
  let(:provider) { create(:user, role: "provider") }
  let(:headers) { auth_headers_for(provider) }

  describe "GET /api/v1/provider/businesses" do
    let!(:business1) { create(:business, user: provider) }
    let!(:business2) { create(:business, user: provider) }
    let!(:other_business) { create(:business) }

    it "returns provider's businesses" do
      get "/api/v1/provider/businesses", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["businesses"].length).to eq(2)
      expect(json["businesses"].map { |b| b["id"] }).to contain_exactly(business1.id, business2.id)
    end

    it "requires authentication" do
      get "/api/v1/provider/businesses"

      expect(response).to have_http_status(:unauthorized)
    end

    it "requires provider role" do
      customer = create(:user, role: "customer")
      get "/api/v1/provider/businesses", headers: auth_headers_for(customer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/provider/businesses/:id" do
    let(:business) { create(:business, user: provider) }

    it "returns business details" do
      get "/api/v1/provider/businesses/#{business.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["business"]["id"]).to eq(business.id)
    end

    it "returns 404 for other provider's business" do
      other_business = create(:business)
      get "/api/v1/provider/businesses/#{other_business.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/provider/businesses" do
    let(:valid_params) do
      {
        name: "Test Business",
        category: "salon",
        description: "A test business",
        address: "123 Test St",
        city: "Test City",
        phone: "+1234567890",
      }
    end

    context "with valid params" do
      it "creates a business" do
        expect do
          post "/api/v1/provider/businesses", params: { business: valid_params }, headers: headers
        end.to change(Business, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["business"]["name"]).to eq("Test Business")
        expect(json["business"]["user_id"]).to eq(provider.id)
      end
    end

    context "with invalid params" do
      it "returns validation errors" do
        post "/api/v1/provider/businesses",
             params: { business: { name: "" } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    it "requires authentication" do
      post "/api/v1/provider/businesses", params: { business: valid_params }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/provider/businesses/:id" do
    let(:business) { create(:business, user: provider, name: "Old Name") }

    context "with valid params" do
      it "updates business" do
        patch "/api/v1/provider/businesses/#{business.id}",
              params: { business: { name: "New Name" } },
              headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["business"]["name"]).to eq("New Name")
        expect(business.reload.name).to eq("New Name")
      end
    end

    context "with invalid params" do
      it "returns validation errors" do
        patch "/api/v1/provider/businesses/#{business.id}",
              params: { business: { name: "" } },
              headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "prevents updating other provider's business" do
      other_business = create(:business)
      patch "/api/v1/provider/businesses/#{other_business.id}",
            params: { business: { name: "Hacked" } },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/provider/businesses/:id" do
    let(:business) { create(:business, user: provider) }

    it "soft deletes business" do
      delete "/api/v1/provider/businesses/#{business.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(business.reload.discarded?).to be true
    end

    it "prevents deleting other provider's business" do
      other_business = create(:business)
      delete "/api/v1/provider/businesses/#{other_business.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/provider/businesses/:id/services" do
    let(:business) { create(:business, user: provider) }
    let!(:service1) { create(:service, business: business) }
    let!(:service2) { create(:service, business: business) }

    it "returns business services" do
      get "/api/v1/provider/businesses/#{business.id}/services", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["services"].length).to eq(2)
    end
  end

  describe "POST /api/v1/provider/businesses/:id/services" do
    let(:business) { create(:business, user: provider) }
    let(:valid_params) do
      {
        name: "Test Service",
        description: "A test service",
        price: 50.0,
        duration: 60,
      }
    end

    it "creates a service for the business" do
      expect do
        post "/api/v1/provider/businesses/#{business.id}/services",
             params: { service: valid_params },
             headers: headers
      end.to change(Service, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["service"]["business_id"]).to eq(business.id)
    end
  end

  describe "GET /api/v1/provider/businesses/:id/bookings" do
    let(:business) { create(:business, user: provider) }
    let(:service) { create(:service, business: business) }
    let!(:booking1) { create(:booking, service: service) }
    let!(:booking2) { create(:booking, service: service) }

    it "returns business bookings" do
      get "/api/v1/provider/businesses/#{business.id}/bookings", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["bookings"].length).to eq(2)
    end
  end

  describe "GET /api/v1/provider/businesses/:id/stats" do
    let(:business) { create(:business, user: provider) }

    it "returns business statistics" do
      get "/api/v1/provider/businesses/#{business.id}/stats", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["stats"]).to be_present
    end
  end
end
