# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Customer::Bookings", type: :request do
  let(:customer) { create(:user, role: "customer") }
  let(:provider) { create(:user, role: "provider") }
  let(:business) { create(:business, user: provider) }
  let(:service) { create(:service, business: business) }
  let(:headers) { auth_headers_for(customer) }

  describe "GET /api/v1/customer/bookings" do
    let!(:booking1) { create(:booking, user: customer, service: service) }
    let!(:booking2) { create(:booking, user: customer, service: service) }
    let!(:other_booking) { create(:booking, service: service) }

    it "returns customer's bookings" do
      get "/api/v1/customer/bookings", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["bookings"].length).to eq(2)
      expect(json["bookings"].map { |b| b["id"] }).to contain_exactly(booking1.id, booking2.id)
    end

    it "requires authentication" do
      get "/api/v1/customer/bookings"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/customer/bookings/:id" do
    let(:booking) { create(:booking, user: customer, service: service) }

    it "returns booking details" do
      get "/api/v1/customer/bookings/#{booking.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["booking"]["id"]).to eq(booking.id)
    end

    it "returns 404 for other user's booking" do
      other_booking = create(:booking, service: service)
      get "/api/v1/customer/bookings/#{other_booking.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/customer/bookings" do
    let(:valid_params) do
      {
        service_id: service.id,
        start_time: 1.day.from_now.iso8601,
        notes: "Test booking",
      }
    end

    context "with valid params" do
      it "creates a booking" do
        expect do
          post "/api/v1/customer/bookings", params: { booking: valid_params }, headers: headers
        end.to change(Booking, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["booking"]["service_id"]).to eq(service.id)
        expect(json["booking"]["user_id"]).to eq(customer.id)
      end
    end

    context "with invalid params" do
      it "returns validation errors" do
        post "/api/v1/customer/bookings",
             params: { booking: { service_id: nil } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_present
      end
    end

    it "requires authentication" do
      post "/api/v1/customer/bookings", params: { booking: valid_params }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/customer/bookings/:id" do
    let(:booking) { create(:booking, user: customer, service: service, status: "pending") }

    context "with valid params" do
      it "updates booking" do
        patch "/api/v1/customer/bookings/#{booking.id}",
              params: { booking: { notes: "Updated notes" } },
              headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["booking"]["notes"]).to eq("Updated notes")
      end
    end

    it "prevents updating other user's booking" do
      other_booking = create(:booking, service: service)
      patch "/api/v1/customer/bookings/#{other_booking.id}",
            params: { booking: { notes: "Hacked" } },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/customer/bookings/:id/confirm" do
    let(:booking) { create(:booking, user: customer, service: service, status: "pending") }

    it "confirms booking" do
      post "/api/v1/customer/bookings/#{booking.id}/confirm", headers: headers

      expect(response).to have_http_status(:ok)
      expect(booking.reload.status).to eq("confirmed")
    end

    it "returns error if already confirmed" do
      booking.update(status: "confirmed")
      post "/api/v1/customer/bookings/#{booking.id}/confirm", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/customer/bookings/:id/cancel" do
    let(:booking) { create(:booking, user: customer, service: service, status: "confirmed") }

    it "cancels booking" do
      post "/api/v1/customer/bookings/#{booking.id}/cancel", headers: headers

      expect(response).to have_http_status(:ok)
      expect(booking.reload.status).to eq("cancelled")
    end

    it "returns error if already cancelled" do
      booking.update(status: "cancelled")
      post "/api/v1/customer/bookings/#{booking.id}/cancel", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/customer/bookings/:id/complete" do
    let(:booking) { create(:booking, user: customer, service: service, status: "confirmed") }

    it "completes booking" do
      post "/api/v1/customer/bookings/#{booking.id}/complete", headers: headers

      expect(response).to have_http_status(:ok)
      expect(booking.reload.status).to eq("completed")
    end
  end

  describe "DELETE /api/v1/customer/bookings/:id" do
    let(:booking) { create(:booking, user: customer, service: service, status: "pending") }

    it "deletes booking" do
      expect do
        delete "/api/v1/customer/bookings/#{booking.id}", headers: headers
      end.to change(Booking, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "prevents deleting confirmed bookings" do
      booking.update(status: "confirmed")
      delete "/api/v1/customer/bookings/#{booking.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
