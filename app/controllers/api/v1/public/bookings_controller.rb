# frozen_string_literal: true

module Api
  module V1
    module Public
      class BookingsController < ApplicationController
        # Public controller - no authentication required.
        # Allows guests to view booking confirmation by short_booking_id only.

        # GET /api/v1/public/bookings/:short_booking_id
        def show
          booking = Booking.find_by(short_booking_id: params[:short_booking_id])
          return render json: { error: "Booking not found" }, status: :not_found unless booking

          primary_service = booking.services.first || booking.booking_service_items.first&.service

          render json: {
            short_booking_id: booking.short_booking_id,
            service_name: primary_service&.translated_name,
            business_name: booking.business&.translated_name,
            business_slug: booking.business&.translated_slug,
            date: booking.date&.to_s,
            start_time: booking.start_time&.strftime("%H:%M"),
            end_time: booking.end_time&.strftime("%H:%M"),
            status: booking.status,
            total_price: booking.total_price,
            duration_minutes: booking.duration_minutes,
            customer_name: booking.customer_name,
          }
        end
      end
    end
  end
end
