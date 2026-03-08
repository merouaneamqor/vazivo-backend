# frozen_string_literal: true

class BookingService
  attr_reader :errors

  def initialize(user)
    @user = user
    @errors = []
  end

  def self.create_guest(params)
    # Ensure indifferent access so params[:service_id] works (e.g. when passed a plain Hash)
    if params.is_a?(Hash) && !params.is_a?(ActiveSupport::HashWithIndifferentAccess)
      params = params.with_indifferent_access
    end
    service = Service.kept.find_by(id: params[:service_id])
    return { success: false, errors: ["Service not found"] } unless service

    return { success: false, errors: ["Business is not available"] } unless service.business.kept?

    user_id = resolve_guest_user_id(params)

    date_str = params[:date].to_s
    start_str = params[:start_time].to_s.strip
    start_str = start_str.slice(0, 5) if start_str.length > 5
    return { success: false, errors: ["Invalid date or start time"] } if date_str.blank? || start_str.blank?

    availability = AvailabilityService.new(service)
    unless availability.available?(date_str, start_str)
      return { success: false, errors: ["This time slot is not available"] }
    end

    # Default staff to business owner if not specified
    staff_id = params[:staff_id].presence || service.business.user_id
    business = service.business

    total_duration = service.duration
    total_price = service.price

    start_time = Time.zone.parse("#{date_str} #{start_str}:00")
    end_time = start_time + total_duration.minutes
    end_time_str = end_time.strftime("%H:%M")

    booking = Booking.new(
      user_id: user_id,
      staff_id: staff_id,
      business: business,
      date: date_str,
      start_time: start_str,
      end_time: end_time_str,
      total_price: total_price,
      notes: params[:special_requests].presence || params[:notes],
      number_of_guests: params[:number_of_guests],
      customer_name: params[:customer_name],
      customer_phone: params[:customer_phone],
      customer_email: params[:customer_email]
    )

    Booking.transaction do
      unless booking.save
        return { success: false, errors: booking.errors.full_messages }
      end

      booking.booking_service_items.create!(
        service_id: service.id,
        staff_id: staff_id,
        price: total_price,
        duration_minutes: total_duration,
        position: 0
      )
    end

    enqueue_booking_notification(booking.id, "created")
    record_event(booking, "created", { source: "guest" })
    discord_notify_new_booking(booking)
    { success: true, booking: booking }
  end

  def self.discord_notify_new_booking(booking)
    customer = booking.user ? booking.user.name : (booking.customer_name.presence || booking.customer_email.presence || "Guest")
    primary_service = booking.services.first || booking.booking_service_items.first&.service
    DiscordNotifier.notify_embed(
      title: "New booking",
      description: "A new appointment was booked.",
      fields: [
        { name: "Business", value: booking.business.translated_name, inline: true },
        { name: "Service", value: primary_service&.translated_name || "Service", inline: true },
        { name: "Date", value: booking.date.to_s, inline: true },
        { name: "Time", value: booking.start_time.strftime("%H:%M"), inline: true },
        { name: "Customer", value: customer, inline: true },
        { name: "Status", value: booking.status, inline: true },
      ],
      color: 0x57f287 # green
    )
  rescue StandardError => e
    Rails.logger.warn("[BookingService] Discord notify failed: #{e.message}")
  end

  # Enqueue notification job; rescue Redis/Sidekiq connection errors so booking actions still succeed.
  # When REDIS_URL uses an internal hostname (e.g. Redis.railway.internal) that doesn't resolve from the API,
  # set REDIS_PUBLIC_URL on the API service so jobs can be enqueued, or notifications will be skipped.
  def self.enqueue_booking_notification(booking_id, event)
    return unless defined?(BookingNotificationJob)

    BookingNotificationJob.perform_later(booking_id, event)
  rescue StandardError => e
    raise unless redis_connection_error?(e)

    Rails.logger.warn("[BookingService] Could not enqueue BookingNotificationJob(#{booking_id}, #{event}): #{e.class} - #{e.message}")
    if defined?(Sentry)
      Sentry.capture_message("Redis unreachable when enqueueing BookingNotificationJob", level: :warning,
                                                                                         extra: { booking_id: booking_id, event: event, error: e.message })
    end
  end

  def self.redis_connection_error?(e)
    return true if e.is_a?(SocketError) || e.is_a?(Errno::ECONNREFUSED)
    return true if defined?(RedisClient::CannotConnectError) && e.is_a?(RedisClient::CannotConnectError)
    return true if e.message.to_s.include?("does not resolve") || e.message.to_s.include?("Cannot connect")

    false
  end

  def self.record_event(booking, event_type, metadata = {})
    return unless defined?(BookingEvent)

    BookingEvent.create!(
      booking_id: booking.id,
      event_type: event_type,
      metadata: metadata,
      created_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.warn("[BookingService] Failed to record booking event #{event_type} for #{booking.id}: #{e.class} - #{e.message}")
  end

  def self.resolve_guest_user_id(params)
    email = params[:customer_email].to_s.strip.presence
    phone = params[:customer_phone].to_s.strip.presence
    return nil if email.blank? && phone.blank?

    user = nil
    user = User.kept.find_by("LOWER(email) = ?", email.downcase) if email.present?
    if phone.present?
      user ||= User.kept.find_by("REPLACE(REPLACE(REPLACE(COALESCE(phone,''), ' ', ''), '-', ''), '+', '') = ?",
                                 Booking.normalize_phone_for_lookup(phone))
    end
    user&.id
  end

  def create(params, skip_availability_check: false, confirm_immediately: false, skip_business_hours_check: false)
    services_param = params[:services]
    if services_param.is_a?(Array) && services_param.size >= 1
      return create_with_services(
        params,
        skip_availability_check: skip_availability_check,
        confirm_immediately: confirm_immediately,
        skip_business_hours_check: skip_business_hours_check
      )
    end

    # Fallback: single service payload -> multi-service flow
    service_id = params[:service_id]
    unless service_id.present?
      @errors = ["Service not found"]
      return { success: false, errors: @errors }
    end

    multi_params = params.merge(
      services: [
        {
          service_id: service_id,
          staff_id: params[:staff_id],
          price: params[:price],
          duration_minutes: params[:duration_minutes],
        },
      ]
    )

    create_with_services(
      multi_params,
      skip_availability_check: skip_availability_check,
      confirm_immediately: confirm_immediately,
      skip_business_hours_check: skip_business_hours_check
    )
  end

  # Create one booking with multiple service line items (booking_services).
  # Params: :services => [{ service_id:, staff_id?:, price?:, duration_minutes?: }, ...], :date, :start_time, :customer_name, :customer_phone, :customer_email, :notes
  def create_with_services(params, skip_availability_check: false, confirm_immediately: false, skip_business_hours_check: false)
    items = params[:services].to_a
    if items.empty?
      @errors = ["At least one service is required"]
      return { success: false, errors: @errors }
    end

    services = []
    items.each do |h|
      svc = Service.kept.find_by(id: h[:service_id] || h["service_id"])
      unless svc
        @errors = ["Service not found"]
        return { success: false, errors: @errors }
      end
      services << {
        service: svc,
        staff_id: (h[:staff_id] || h["staff_id"]).presence,
        price: h[:price] || h["price"],
        duration_minutes: h[:duration_minutes] || h["duration_minutes"]
      }
    end

    first = services.first
    business = first[:service].business
    unless business.kept?
      @errors = ["Business is not available"]
      return { success: false, errors: @errors }
    end

    same_business = services.all? { |s| s[:service].business_id == business.id }
    unless same_business
      @errors = ["All services must belong to the same business"]
      return { success: false, errors: @errors }
    end

    total_duration = services.sum do |s|
      (s[:duration_minutes].presence && s[:duration_minutes].to_i) || s[:service].duration
    end
    total_price = services.sum do |s|
      (s[:price].presence && s[:price].to_f) || s[:service].price.to_f
    end

    date_str = params[:date].to_s
    start_str = params[:start_time].to_s.strip
    start_str = start_str.slice(0, 5) if start_str.length > 5
    return { success: false, errors: ["Invalid date or start time"] } if date_str.blank? || start_str.blank?

    start_time = Time.zone.parse("#{date_str} #{start_str}:00")
    end_time = start_time + total_duration.minutes
    end_time_str = end_time.strftime("%H:%M")

    unless skip_availability_check
      availability = AvailabilityService.new(first[:service])
      unless availability.available?(date_str, start_str)
        @errors = ["This time slot is not available"]
        return { success: false, errors: @errors }
      end
    end

    staff_id = first[:staff_id].presence || business.user_id
    customer = resolve_customer(business.id, params, provider_flow: confirm_immediately)

    # Provider-created booking: build on business so booking.user_id = customer (not provider)
    booking = (confirm_immediately ? business.bookings : @user.bookings).build(
      business: business,
      staff_id: staff_id,
      user_id: customer[:user_id],
      date: date_str,
      start_time: start_str,
      end_time: end_time_str,
      total_price: total_price,
      notes: params[:special_requests].presence || params[:notes],
      number_of_guests: params[:number_of_guests],
      customer_name: customer[:customer_name],
      customer_phone: customer[:customer_phone],
      customer_email: customer[:customer_email]
    )

    if confirm_immediately
      booking.status = :confirmed
      booking.confirmed_at = Time.current
    end

    booking.skip_business_hours_check = true if skip_business_hours_check

    if booking.save
      services.each_with_index do |s, idx|
        duration_min = (s[:duration_minutes].presence && s[:duration_minutes].to_i) || s[:service].duration
        price_val = (s[:price].presence && s[:price].to_f) || s[:service].price.to_f
        booking.booking_service_items.create!(
          service_id: s[:service].id,
          staff_id: s[:staff_id].presence,
          price: price_val,
          duration_minutes: duration_min,
          position: idx
        )
      end
      event = confirm_immediately ? "confirmed" : "created"
      self.class.enqueue_booking_notification(booking.id, event)
      self.class.record_event(booking, event, { source: (confirm_immediately ? "provider" : "customer") })
      self.class.discord_notify_new_booking(booking)
      { success: true, booking: booking }
    else
      @errors = booking.errors.full_messages
      { success: false, errors: @errors }
    end
  end

  def cancel(booking)
    unless BookingPolicy.new(@user, booking).cancel?
      @errors = ["You are not authorized to cancel this booking"]
      return { success: false, errors: @errors }
    end

    unless booking.can_cancel?
      @errors = ["This booking cannot be cancelled"]
      return { success: false, errors: @errors }
    end

    if booking.cancel!
      self.class.enqueue_booking_notification(booking.id, "cancelled")
      self.class.record_event(booking, "cancelled", { actor_id: @user&.id })
      { success: true, booking: booking }
    else
      @errors = booking.errors.full_messages
      { success: false, errors: @errors }
    end
  end

  def confirm(booking)
    unless BookingPolicy.new(@user, booking).confirm?
      @errors = ["You are not authorized to confirm this booking"]
      return { success: false, errors: @errors }
    end

    unless booking.can_confirm?
      @errors = ["This booking cannot be confirmed"]
      return { success: false, errors: @errors }
    end

    if booking.confirm!
      self.class.enqueue_booking_notification(booking.id, "confirmed")
      self.class.record_event(booking, "confirmed", { actor_id: @user&.id })
      { success: true, booking: booking }
    else
      @errors = booking.errors.full_messages
      { success: false, errors: @errors }
    end
  end

  def complete(booking)
    unless BookingPolicy.new(@user, booking).complete?
      @errors = ["You are not authorized to complete this booking"]
      return { success: false, errors: @errors }
    end

    unless booking.can_complete?
      @errors = ["This booking cannot be completed"]
      return { success: false, errors: @errors }
    end

    if booking.complete!
      self.class.enqueue_booking_notification(booking.id, "completed")
      self.class.record_event(booking, "completed", { actor_id: @user&.id })
      { success: true, booking: booking }
    else
      @errors = booking.errors.full_messages
      { success: false, errors: @errors }
    end
  end

  def reschedule(booking, new_date, new_start_time, skip_availability_check: false)
    unless BookingPolicy.new(@user, booking).update?
      @errors = ["You are not authorized to reschedule this booking"]
      return { success: false, errors: @errors }
    end

    unless booking.can_cancel?
      @errors = ["This booking cannot be rescheduled"]
      return { success: false, errors: @errors }
    end

    # Check new slot availability (skip for provider manual changes)
    unless skip_availability_check
      primary_service = booking.services.first || booking.booking_service_items.first&.service
      if primary_service
        availability = AvailabilityService.new(primary_service)
        unless availability.available?(new_date, new_start_time)
          @errors = ["The new time slot is not available"]
          return { success: false, errors: @errors }
        end
      end
    end

    old_attrs = { date: booking.date, start_time: booking.start_time }
    if booking.update(date: new_date, start_time: new_start_time, end_time: nil)
      self.class.enqueue_booking_notification(booking.id, "rescheduled")
      self.class.record_event(
        booking,
        "rescheduled",
        {
          actor_id: @user&.id,
          from_date: old_attrs[:date],
          from_start_time: old_attrs[:start_time],
          to_date: new_date,
          to_start_time: new_start_time,
        }
      )
      { success: true, booking: booking }
    else
      @errors = booking.errors.full_messages
      { success: false, errors: @errors }
    end
  end

  private

  # Resolve customer fields from client_id (provider) or params. Returns hash with :customer_name, :customer_phone, :customer_email, :user_id.
  # When provider_flow is true and no client_id, booking.user_id is nil (provider creating for walk-in).
  def resolve_customer(business_id, params, provider_flow: false)
    client_id = params[:client_id].presence && params[:client_id].to_s
    if client_id.present?
      client = Client.find_by(id: client_id, business_id: business_id)
      if client
        return {
          customer_name: client.name,
          customer_phone: client.phone,
          customer_email: client.email,
          user_id: client.user_id,
        }
      end
    end
    user_id = provider_flow ? nil : @user&.id
    customer_name = params[:customer_name].presence
    customer_name = [params[:customer_first_name], params[:customer_last_name]].compact.join(" ").strip.presence if customer_name.blank? && (params[:customer_first_name].present? || params[:customer_last_name].present?)
    {
      customer_name: customer_name,
      customer_phone: params[:customer_phone],
      customer_email: params[:customer_email],
      user_id: user_id,
    }
  end
end
