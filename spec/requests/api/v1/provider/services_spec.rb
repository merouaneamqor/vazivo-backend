# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Provider::Services", type: :request do
  let(:provider) { create(:user, role: "provider") }
  let(:business) { create(:business, user: provider) }
  let(:headers) { auth_headers_for(provider) }

  describe "GET /api/v1/provider/services/:id" do
    let(:service) { create(:service, business: business) }

    it "returns service details" do
      get "/api/v1/provider/services/#{service.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["service"]["id"]).to eq(service.id)
    end

    it "returns 404 for other provider's service" do
      other_service = create(:service)
      get "/api/v1/provider/services/#{other_service.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      get "/api/v1/provider/services/#{service.id}"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/provider/services/:id" do
    let(:service) { create(:service, business: business, name: "Old Name", price: 50.0) }

    context "with valid params" do
      it "updates service" do
        patch "/api/v1/provider/services/#{service.id}",
              params: { service: { name: "New Name", price: 75.0 } },
              headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["service"]["name"]).to eq("New Name")
        expect(json["service"]["price"]).to eq("75.0")
        expect(service.reload.name).to eq("New Name")
      end
    end

    context "with invalid params" do
      it "returns validation errors" do
        patch "/api/v1/provider/services/#{service.id}",
              params: { service: { price: -10 } },
              headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    it "prevents updating other provider's service" do
      other_service = create(:service)
      patch "/api/v1/provider/services/#{other_service.id}",
            params: { service: { name: "Hacked" } },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/provider/services/:id" do
    let(:service) { create(:service, business: business) }

    it "soft deletes service" do
      delete "/api/v1/provider/services/#{service.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(service.reload.discarded?).to be true
    end

    it "prevents deleting service with active bookings" do
      create(:booking, service: service, status: "confirmed")
      delete "/api/v1/provider/services/#{service.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents deleting other provider's service" do
      other_service = create(:service)
      delete "/api/v1/provider/services/#{other_service.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/provider/services/:id/availability" do
    let(:service) { create(:service, business: business) }

    it "returns service availability" do
      get "/api/v1/provider/services/#{service.id}/availability",
          params: { date: Date.today.to_s },
          headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["availability"]).to be_present
    end

    it "requires date parameter" do
      get "/api/v1/provider/services/#{service.id}/availability", headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end
end
