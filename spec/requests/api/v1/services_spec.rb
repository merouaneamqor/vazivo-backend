# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Services", type: :request do
  let(:provider) { create(:user, :provider) }
  let(:customer) { create(:user, :customer) }
  let(:admin) { create(:user, :admin) }
  let(:business) { create(:business, user: provider) }
  let!(:service) { create(:service, business: business, name: "Massage", duration: 60, price: 100) }

  describe "GET /api/v1/services/:id" do
    context "when authenticated" do
      it "returns the service" do
        sign_in(customer)
        auth_get "/api/v1/services/#{service.id}"

        expect(response).to have_http_status(:ok)
        expect(json_response[:service][:name]).to eq("Massage")
      end
    end

    context "when not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/services/#{service.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "returns 404 for non-existent service" do
      sign_in(customer)
      auth_get "/api/v1/services/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/services/:id/availability" do
    let(:date) { Date.tomorrow.strftime("%Y-%m-%d") }

    it "returns available time slots for a date" do
      sign_in(customer)
      auth_get "/api/v1/services/#{service.id}/availability", params: { date: date }

      expect(response).to have_http_status(:ok)
      expect(json_response[:service_id]).to eq(service.id)
      expect(json_response[:slots]).to be_an(Array)
    end

    it "returns availability calendar when end_date provided" do
      sign_in(customer)
      end_date = (Date.tomorrow + 7.days).strftime("%Y-%m-%d")
      auth_get "/api/v1/services/#{service.id}/availability", params: { date: date, end_date: end_date }

      expect(response).to have_http_status(:ok)
      expect(json_response[:calendar]).to be_an(Array)
    end
  end

  describe "POST /api/v1/businesses/:business_id/services" do
    let(:valid_params) do
      {
        service: {
          name: "New Service",
          description: "A new service",
          duration: 45,
          price: 75,
        },
      }
    end

    context "as the business owner" do
      it "creates a new service" do
        sign_in(provider)

        expect do
          auth_post "/api/v1/businesses/#{business.id}/services", params: valid_params
        end.to change(Service, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:service][:name]).to eq("New Service")
      end
    end

    context "as an admin" do
      it "creates a new service" do
        sign_in(admin)

        expect do
          auth_post "/api/v1/businesses/#{business.id}/services", params: valid_params
        end.to change(Service, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "as a customer" do
      it "returns forbidden" do
        sign_in(customer)
        auth_post "/api/v1/businesses/#{business.id}/services", params: valid_params

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with invalid params" do
      it "returns validation errors" do
        sign_in(provider)
        auth_post "/api/v1/businesses/#{business.id}/services", params: { service: { name: "" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response[:errors]).to be_present
      end
    end
  end

  describe "PATCH /api/v1/services/:id" do
    context "as the business owner" do
      it "updates the service" do
        sign_in(provider)
        auth_patch "/api/v1/services/#{service.id}", params: { service: { name: "Updated Service" } }

        expect(response).to have_http_status(:ok)
        expect(json_response[:service][:name]).to eq("Updated Service")
      end
    end

    context "as another provider" do
      let(:other_provider) { create(:user, :provider) }

      it "returns forbidden" do
        sign_in(other_provider)
        auth_patch "/api/v1/services/#{service.id}", params: { service: { name: "Hacked" } }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/services/:id" do
    context "as the business owner" do
      it "soft deletes the service" do
        sign_in(provider)

        expect do
          auth_delete "/api/v1/services/#{service.id}"
        end.to change { service.reload.discarded? }.from(false).to(true)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as a customer" do
      it "returns forbidden" do
        sign_in(customer)
        auth_delete "/api/v1/services/#{service.id}"

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
