# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Customer::Reviews", type: :request do
  let(:customer) { create(:user, role: "customer") }
  let(:provider) { create(:user, role: "provider") }
  let(:business) { create(:business, user: provider) }
  let(:service) { create(:service, business: business) }
  let(:booking) { create(:booking, user: customer, service: service, status: "completed") }
  let(:headers) { auth_headers_for(customer) }

  describe "POST /api/v1/customer/reviews" do
    let(:valid_params) do
      {
        booking_id: booking.id,
        rating: 5,
        comment: "Great service!",
      }
    end

    context "with valid params" do
      it "creates a review" do
        expect do
          post "/api/v1/customer/reviews", params: { review: valid_params }, headers: headers
        end.to change(Review, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["review"]["rating"]).to eq(5)
        expect(json["review"]["user_id"]).to eq(customer.id)
      end
    end

    context "with invalid params" do
      it "returns validation errors for missing rating" do
        post "/api/v1/customer/reviews",
             params: { review: { booking_id: booking.id, comment: "Test" } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error for invalid rating" do
        post "/api/v1/customer/reviews",
             params: { review: { booking_id: booking.id, rating: 6 } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "prevents reviewing non-completed booking" do
      pending_booking = create(:booking, user: customer, service: service, status: "pending")
      post "/api/v1/customer/reviews",
           params: { review: { booking_id: pending_booking.id, rating: 5 } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents duplicate reviews" do
      create(:review, user: customer, booking: booking)
      post "/api/v1/customer/reviews", params: { review: valid_params }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "requires authentication" do
      post "/api/v1/customer/reviews", params: { review: valid_params }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/customer/reviews/:id" do
    let(:review) { create(:review, user: customer, booking: booking) }

    it "returns review details" do
      get "/api/v1/customer/reviews/#{review.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["review"]["id"]).to eq(review.id)
    end

    it "returns 404 for other user's review" do
      other_review = create(:review)
      get "/api/v1/customer/reviews/#{other_review.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/customer/reviews/:id" do
    let(:review) { create(:review, user: customer, booking: booking, rating: 4) }

    context "with valid params" do
      it "updates review" do
        patch "/api/v1/customer/reviews/#{review.id}",
              params: { review: { rating: 5, comment: "Updated comment" } },
              headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["review"]["rating"]).to eq(5)
        expect(review.reload.rating).to eq(5)
      end
    end

    context "with invalid params" do
      it "returns validation errors" do
        patch "/api/v1/customer/reviews/#{review.id}",
              params: { review: { rating: 0 } },
              headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "prevents updating other user's review" do
      other_review = create(:review)
      patch "/api/v1/customer/reviews/#{other_review.id}",
            params: { review: { rating: 1 } },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/customer/reviews/:id" do
    let(:review) { create(:review, user: customer, booking: booking) }

    it "deletes review" do
      expect do
        delete "/api/v1/customer/reviews/#{review.id}", headers: headers
      end.to change(Review, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "prevents deleting other user's review" do
      other_review = create(:review)
      delete "/api/v1/customer/reviews/#{other_review.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
