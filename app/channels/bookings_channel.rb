# frozen_string_literal: true

class BookingsChannel < ApplicationCable::Channel
  def subscribed
    if params[:business_id]
      # Provider subscribing to their business bookings
      business = Business.find(params[:business_id])
      if current_user.can_manage_business?(business)
        stream_from "bookings:business:#{params[:business_id]}"
      else
        reject
      end
    else
      # Customer subscribing to their own bookings
      stream_from "bookings:user:#{current_user.id}"
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Broadcast a booking update
  def self.broadcast_booking_update(booking)
    # Notify the customer
    ActionCable.server.broadcast(
      "bookings:user:#{booking.user_id}",
      {
        type: "booking_updated",
        booking: BookingSerializer.new(booking).as_json,
      }
    )

    # Notify the business owner
    ActionCable.server.broadcast(
      "bookings:business:#{booking.business_id}",
      {
        type: "booking_updated",
        booking: BookingSerializer.new(booking).as_json,
      }
    )
  end
end
