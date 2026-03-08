# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Bookings", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:provider) { create(:user, :provider) }
  let(:business) { create(:business, user: provider) }
  let(:service) { create(:service, business: business) }

  describe "GET /api/v1/bookings" do
    before do
      create_list(:booking, 3, user: customer, service: service)
      create(:booking, service: service) # Different user
    end

    it "returns only the current user bookings" do
      get "/api/v1/bookings", headers: auth_headers_for(customer)

      expect(response).to have_http_status(:ok)
      expect(json_response[:bookings].length).to eq(3)
    end

    it "filters by status" do
      create(:booking, :confirmed, user: customer, service: service)

      get "/api/v1/bookings", params: { status: "confirmed" }, headers: auth_headers_for(customer)

      expect(response).to have_http_status(:ok)
      expect(json_response[:bookings].all? { |b| b[:status] == "confirmed" }).to be true
    end

    it "filters upcoming bookings" do
      create(:booking, :past, user: customer, service: service)

      get "/api/v1/bookings", params: { upcoming: "true" }, headers: auth_headers_for(customer)

      expect(response).to have_http_status(:ok)
      expect(json_response[:bookings].all? { |b| Date.parse(b[:date]) >= Date.current }).to be true
    end
  end

  describe "POST /api/v1/bookings" do
    let(:valid_params) do
      {
        booking: {
          service_id: service.id,
          date: Date.tomorrow.to_s,
          start_time: "10:00",
        },
      }
    end

    context "with valid parameters" do
      it "creates a new booking" do
        expect do
          post "/api/v1/bookings", params: valid_params, headers: auth_headers_for(customer), as: :json
        end.to change(Booking, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:booking][:status]).to eq("pending")
      end
    end

    context "with conflicting time slot" do
      before do
        create(:booking, service: service, date: Date.tomorrow, start_time: "10:00")
      end

      it "returns error for double booking" do
        post "/api/v1/bookings", params: valid_params, headers: auth_headers_for(customer), as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response[:errors]).to include("This time slot is not available")
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        post "/api/v1/bookings", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/bookings/:id/confirm" do
    let(:booking) { create(:booking, service: service, user: customer) }

    context "as the business owner" do
      it "confirms the booking" do
        post "/api/v1/bookings/#{booking.id}/confirm", headers: auth_headers_for(provider)

        expect(response).to have_http_status(:ok)
        expect(json_response[:booking][:status]).to eq("confirmed")
      end
    end

    context "as the customer" do
      it "returns forbidden" do
        post "/api/v1/bookings/#{booking.id}/confirm", headers: auth_headers_for(customer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/bookings/:id/cancel" do
    let(:booking) { create(:booking, service: service, user: customer) }

    context "as the customer" do
      it "cancels the booking" do
        post "/api/v1/bookings/#{booking.id}/cancel", headers: auth_headers_for(customer)

        expect(response).to have_http_status(:ok)
        expect(json_response[:booking][:status]).to eq("cancelled")
      end
    end

    context "as the business owner" do
      it "can also cancel the booking" do
        post "/api/v1/bookings/#{booking.id}/cancel", headers: auth_headers_for(provider)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
