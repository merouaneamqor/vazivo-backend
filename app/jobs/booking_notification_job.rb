# frozen_string_literal: true

class BookingNotificationJob < ApplicationJob
  queue_as :default

  def perform(booking_id, event_type)
    booking = Booking.find_by(id: booking_id)
    return unless booking

    # Broadcast real-time update
    BookingsChannel.broadcast_booking_update(booking)

    # Send SMS and email notifications based on event type
    case event_type
    when "created"
      send_sms_confirmation(booking)
      customer_email = booking.user_id.present? ? booking.user&.email : booking.customer_email
      BookingMailer.booking_created_for_customer(booking).deliver_later if customer_email.present?
      BookingMailer.new_booking_notification(booking).deliver_later
      send_provider_sms(booking)
      Rails.logger.info "New booking notification for booking ##{booking_id}"

    when "confirmed"
      customer_email = booking.user_id.present? ? booking.user&.email : booking.customer_email
      BookingMailer.booking_confirmed_for_customer(booking).deliver_later if customer_email.present?
      Rails.logger.info "Booking confirmed notification for booking ##{booking_id}"

    when "cancelled"
      BookingMailer.booking_cancelled_for_customer(booking).deliver_later
      BookingMailer.booking_cancelled_for_provider(booking).deliver_later
      Rails.logger.info "Booking cancelled notification for booking ##{booking_id}"

    when "completed"
      BookingMailer.review_request(booking).deliver_later
      Rails.logger.info "Booking completed notification for booking ##{booking_id}"

    when "rescheduled"
      customer_email = booking.user_id.present? ? booking.user&.email : booking.customer_email
      BookingMailer.booking_rescheduled_for_customer(booking).deliver_later if customer_email.present?
      BookingMailer.new_booking_notification(booking).deliver_later
      Rails.logger.info "Booking rescheduled notification for booking ##{booking_id}"
    end
  end

  private

  def send_sms_confirmation(booking)
    SmsService.send_booking_confirmation(booking)
  rescue StandardError => e
    Rails.logger.error "[BookingNotificationJob] SMS failed: #{e.message}"
  end

  def send_provider_sms(booking)
    SmsService.send_new_booking_notification_to_provider(booking)
  rescue StandardError => e
    Rails.logger.error "[BookingNotificationJob] Provider SMS failed: #{e.message}"
  end
end
