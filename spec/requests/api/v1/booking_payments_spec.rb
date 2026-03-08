# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BookingPayments", type: :request do
  let(:customer) { create(:user, :customer) }
  let(:other_customer) { create(:user, :customer) }
  let(:business) { create(:business, :with_services) }
  let(:service) { business.services.first }
  let!(:booking) { create(:booking, user: customer, service: service, business: business, total_price: 100) }

  describe "POST /api/v1/booking_payments/create_intent" do
    before do
      allow(Stripe::PaymentIntent).to receive(:create).and_return(
        OpenStruct.new(
          id: "pi_test_123",
          client_secret: "pi_test_123_secret"
        )
      )
    end

    context "as the booking owner" do
      it "creates a payment intent" do
        sign_in(customer)
        auth_post "/api/v1/booking_payments/create_intent", params: { booking_id: booking.id }

        expect(response).to have_http_status(:ok)
        expect(json_response[:client_secret]).to eq("pi_test_123_secret")
        expect(json_response[:payment_intent_id]).to eq("pi_test_123")
      end

      it "creates a booking payment record" do
        sign_in(customer)

        expect do
          auth_post "/api/v1/booking_payments/create_intent", params: { booking_id: booking.id }
        end.to change(BookingPayment, :count).by(1)

        payment = BookingPayment.last
        expect(payment.booking_id).to eq(booking.id)
        expect(payment.amount).to eq(100)
        expect(payment.status).to eq("pending")
      end
    end

    context "as another user" do
      it "returns forbidden" do
        sign_in(other_customer)
        auth_post "/api/v1/booking_payments/create_intent", params: { booking_id: booking.id }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "for a non-existent booking" do
      it "returns not found" do
        sign_in(customer)
        auth_post "/api/v1/booking_payments/create_intent", params: { booking_id: 999_999 }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/booking_payments/confirm" do
    let!(:payment) { create(:booking_payment, booking: booking, user: customer, status: "pending") }

    before do
      allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(
        OpenStruct.new(
          id: payment.stripe_payment_intent_id,
          status: "succeeded"
        )
      )
    end

    context "as the booking owner" do
      it "confirms the payment" do
        sign_in(customer)
        auth_post "/api/v1/booking_payments/confirm", params: { payment_intent_id: payment.stripe_payment_intent_id }

        expect(response).to have_http_status(:ok)
        expect(payment.reload.status).to eq("succeeded")
      end
    end
  end
end
