# frozen_string_literal: true

class BookingMailer < ApplicationMailer
  def booking_created_for_customer(booking)
    email = booking.customer_email_address
    return if email.blank?

    set_booking_ivars(booking)
    subject = booking.status_confirmed? ? "Booking confirmed at #{@business_name}" : "Booking request received – #{@business_name}"
    mail(to: email, subject: subject)
  end

  def booking_confirmed_for_customer(booking)
    email = booking.customer_email_address
    return if email.blank?

    set_booking_ivars(booking)
    mail(to: email, subject: "Booking confirmed at #{@business_name}")
  end

  def booking_cancelled_for_customer(booking)
    email = booking.customer_email_address
    return if email.blank?

    set_booking_ivars(booking)
    mail(to: email, subject: "Booking cancelled – #{@business_name}")
  end

  def booking_cancelled_for_provider(booking)
    owner_email = booking.owner_email
    return if owner_email.blank?

    set_booking_ivars(booking)
    @customer_name = booking.customer_full_name
    mail(to: owner_email, subject: "Booking cancelled – #{@business_name}")
  end

  def review_request(booking)
    email = booking.customer_email_address
    return if email.blank?

    set_booking_ivars(booking)
    @review_url = review_url_for(booking)
    mail(to: email, subject: "How was your visit at #{@business_name}?")
  end

  def booking_rescheduled_for_customer(booking)
    email = booking.customer_email_address
    return if email.blank?

    set_booking_ivars(booking)
    mail(to: email, subject: "Booking rescheduled – #{@business_name}")
  end

  def new_booking_notification(booking)
    owner_email = booking.owner_email
    return if owner_email.blank?

    set_booking_ivars(booking)
    @customer_name = booking.customer_full_name
    mail(to: owner_email, subject: "New booking at #{@business_name}")
  end

  private

  def set_booking_ivars(booking)
    @booking = booking
    @business_name = booking.business_name
    @service_name = booking.primary_service_name
    @date = booking.date&.strftime("%B %d, %Y")
    @time = booking.start_time&.strftime("%l:%M %p")&.strip
    @short_booking_id = booking.short_booking_id
  end

  def review_url_for(booking)
    frontend = ENV["FRONTEND_URL"].presence || "http://localhost:3001"
    base = frontend.chomp("/")
    business_slug = booking.business_slug
    "#{base}/business/#{business_slug}?review=#{booking.short_booking_id}"
  end
end
