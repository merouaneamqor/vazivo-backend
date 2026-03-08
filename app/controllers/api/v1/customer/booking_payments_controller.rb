# frozen_string_literal: true

# Booking payments: customer payments for bookings (Stripe). Not for provider/subscription payments.
module Api
  module V1
    module Customer
      class BookingPaymentsController < BaseController
        before_action :authenticate_user!

        # POST /api/v1/booking_payments/create_intent
        def create_intent
          booking = Booking.find(params[:booking_id])
          authorize booking, :show?

          return render_error("Unauthorized", status: :forbidden) unless booking.user_id == current_user.id

          unless booking.status_pending? || booking.status_confirmed?
            return render_error("Booking is not payable", status: :unprocessable_content)
          end

          begin
            intent = Stripe::PaymentIntent.create({
              amount: (booking.total_price * 100).to_i,
              currency: "mad",
              metadata: {
                booking_id: booking.id,
                user_id: current_user.id,
              },
            })

            BookingPayment.create!(
              booking: booking,
              user: current_user,
              amount: booking.total_price,
              stripe_payment_intent_id: intent.id,
              status: "pending"
            )

            render json: {
              client_secret: intent.client_secret,
              payment_intent_id: intent.id,
            }
          rescue Stripe::StripeError => e
            render_error(e.message, status: :unprocessable_content)
          end
        end

        # POST /api/v1/booking_payments/confirm
        def confirm
          payment = BookingPayment.find_by!(stripe_payment_intent_id: params[:payment_intent_id])

          begin
            intent = Stripe::PaymentIntent.retrieve(params[:payment_intent_id])

            if intent.status == "succeeded"
              payment.mark_as_paid!
              payment.booking.confirm! if payment.booking.status_pending?

              render json: { success: true, status: payment.status }
            else
              render json: { success: false, status: intent.status }
            end
          rescue Stripe::StripeError => e
            render_error(e.message, status: :unprocessable_content)
          end
        end
      end
    end
  end
end
