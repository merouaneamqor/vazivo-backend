# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Provider::Dashboard", type: :request do
  let(:provider) { create(:user, role: "provider") }
  let(:business) { create(:business, user: provider) }
  let(:headers) { auth_headers_for(provider) }

  describe "GET /api/v1/provider/dashboard" do
    it "returns dashboard data" do
      get "/api/v1/provider/dashboard", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key("businesses")
      expect(json).to have_key("stats")
    end

    it "requires authentication" do
      get "/api/v1/provider/dashboard"

      expect(response).to have_http_status(:unauthorized)
    end

    it "requires provider role" do
      customer = create(:user, role: "customer")
      get "/api/v1/provider/dashboard", headers: auth_headers_for(customer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/provider/stats" do
    let(:service) { create(:service, business: business) }

    before do
      create_list(:booking, 3, service: service, status: "confirmed")
      create_list(:booking, 2, service: service, status: "completed")
    end

    it "returns provider statistics" do
      get "/api/v1/provider/stats", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["stats"]).to be_present
      expect(json["stats"]["total_bookings"]).to eq(5)
    end
  end

  describe "GET /api/v1/provider/bookings" do
    let(:service) { create(:service, business: business) }
    let!(:booking1) { create(:booking, service: service) }
    let!(:booking2) { create(:booking, service: service) }
    let!(:other_booking) { create(:booking) }

    it "returns provider's bookings" do
      get "/api/v1/provider/bookings", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["bookings"].length).to eq(2)
      expect(json["bookings"].map { |b| b["id"] }).to contain_exactly(booking1.id, booking2.id)
    end

    it "filters by status" do
      booking1.update(status: "confirmed")
      booking2.update(status: "pending")

      get "/api/v1/provider/bookings", params: { status: "confirmed" }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["bookings"].length).to eq(1)
      expect(json["bookings"].first["id"]).to eq(booking1.id)
    end
  end

  describe "GET /api/v1/provider/calendar" do
    let(:service) { create(:service, business: business) }

    before do
      create(:booking, service: service, start_time: Time.current)
      create(:booking, service: service, start_time: 1.day.from_now)
    end

    it "returns calendar events" do
      get "/api/v1/provider/calendar",
          params: { start_date: Date.today.to_s, end_date: 7.days.from_now.to_date.to_s },
          headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["events"]).to be_present
      expect(json["events"].length).to eq(2)
    end

    it "requires date parameters" do
      get "/api/v1/provider/calendar", headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end
end
