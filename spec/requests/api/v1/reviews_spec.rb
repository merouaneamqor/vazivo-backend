# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Reviews", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:other_customer) { create(:user, :customer) }
  let(:admin) { create(:user, :admin) }
  let(:business) { create(:business, :with_services) }
  let(:service) { business.services.first }
  let!(:completed_booking) { create(:booking, :completed, user: customer, service: service, business: business) }

  describe "POST /api/v1/reviews" do
    let(:valid_params) do
      {
        review: {
          booking_id: completed_booking.id,
          rating: 5,
          comment: "Excellent service!",
        },
      }
    end

    context "as the booking owner" do
      it "creates a new review" do
        sign_in(customer)

        expect do
          auth_post "/api/v1/reviews", params: valid_params
        end.to change(Review, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_response[:review][:rating]).to eq(5)
        expect(json_response[:review][:comment]).to eq("Excellent service!")
      end
    end

    context "for a non-completed booking" do
      let(:pending_booking) { create(:booking, user: customer, service: service, business: business) }

      it "returns validation error" do
        sign_in(customer)
        auth_post "/api/v1/reviews", params: { review: { booking_id: pending_booking.id, rating: 5 } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response[:errors]).to include("You can only review completed bookings")
      end
    end

    context "for another user booking" do
      let(:other_booking) { create(:booking, :completed, user: other_customer, service: service, business: business) }

      it "returns validation error" do
        sign_in(customer)
        auth_post "/api/v1/reviews", params: { review: { booking_id: other_booking.id, rating: 5 } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response[:errors]).to include("You can only review your own bookings")
      end
    end

    context "when booking already has a review" do
      before { create(:review, booking: completed_booking, user: customer, business: business) }

      it "returns validation error" do
        sign_in(customer)
        auth_post "/api/v1/reviews", params: valid_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response[:errors]).to include("Booking already has a review")
      end
    end

    context "with invalid rating" do
      it "returns validation error" do
        sign_in(customer)
        auth_post "/api/v1/reviews", params: { review: { booking_id: completed_booking.id, rating: 6 } }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /api/v1/reviews/:id" do
    let!(:review) { create(:review, booking: completed_booking, user: customer, business: business, rating: 4) }

    context "as the review owner" do
      it "updates the review" do
        sign_in(customer)
        auth_patch "/api/v1/reviews/#{review.id}", params: { review: { rating: 5, comment: "Updated comment" } }

        expect(response).to have_http_status(:ok)
        expect(json_response[:review][:rating]).to eq(5)
        expect(json_response[:review][:comment]).to eq("Updated comment")
      end
    end

    context "as another user" do
      it "returns forbidden" do
        sign_in(other_customer)
        auth_patch "/api/v1/reviews/#{review.id}", params: { review: { rating: 1 } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      it "can update any review" do
        sign_in(admin)
        auth_patch "/api/v1/reviews/#{review.id}", params: { review: { rating: 3 } }

        expect(response).to have_http_status(:ok)
        expect(json_response[:review][:rating]).to eq(3)
      end
    end
  end

  describe "DELETE /api/v1/reviews/:id" do
    let!(:review) { create(:review, booking: completed_booking, user: customer, business: business) }

    context "as the review owner" do
      it "deletes the review" do
        sign_in(customer)

        expect do
          auth_delete "/api/v1/reviews/#{review.id}"
        end.to change(Review, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as another user" do
      it "returns forbidden" do
        sign_in(other_customer)
        auth_delete "/api/v1/reviews/#{review.id}"

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as an admin" do
      it "can delete any review" do
        sign_in(admin)

        expect do
          auth_delete "/api/v1/reviews/#{review.id}"
        end.to change(Review, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
