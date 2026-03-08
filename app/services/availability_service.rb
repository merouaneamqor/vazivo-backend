# frozen_string_literal: true

# Computes available time slots for a service from opening hours and existing bookings.
# Only active (non-cancelled, non-no_show) bookings block slots; cancelled bookings are
# excluded via Booking.active, so those slots become visible on the agenda again.
class AvailabilityService
  SLOT_INTERVAL = 30 # minutes

  def initialize(service)
    @service = service
    @business = service.business
    @duration = service.duration
  end

  # Get available time slots for a specific date (supports multiple intervals per day)
  def available_slots(date)
    return [] if date.blank?

    date = parse_date(date)
    return [] unless date.is_a?(Date) && valid_date?(date)

    day_name = date.strftime("%A").downcase
    intervals = @business.intervals_for_day(day_name)
    return [] if intervals.empty?

    existing_bookings = Booking.joins(:booking_service_items)
      .where(booking_services: { service_id: @service.id })
      .for_date(date)
      .active
      .pluck(:start_time, :end_time)
      .map { |s, e| [s.strftime("%H:%M"), e.strftime("%H:%M")] }

    unavailability_intervals = StaffUnavailability.for_business_on_date(@business.id, date)
      .pluck(:start_time, :end_time)
      .map { |s, e| [s.strftime("%H:%M"), e.strftime("%H:%M")] }

    blocked_intervals = existing_bookings + unavailability_intervals

    intervals.flat_map do |int|
      opening_time = parse_time(int["open"])
      closing_time = parse_time(int["close"])
      generate_slots(date, opening_time, closing_time, blocked_intervals)
    end.sort_by { |s| s[:time] }
  end

  # Check if a specific time slot is available
  def available?(date, start_time)
    return false if date.blank? || start_time.blank?

    slots = available_slots(date)
    time_str = start_time.is_a?(String) ? start_time : start_time.strftime("%H:%M")
    slots.any? { |slot| slot[:time] == time_str && slot[:available] }
  end

  # Get availability for multiple dates
  def availability_calendar(start_date, end_date)
    return [] if start_date.blank? || end_date.blank?

    start_date = parse_date(start_date)
    end_date = parse_date(end_date)
    return [] unless start_date.is_a?(Date) && end_date.is_a?(Date) && start_date <= end_date

    (start_date..end_date).map do |date|
      {
        date: date.to_s,
        day_name: date.strftime("%A"),
        is_open: business_open?(date),
        slots: available_slots(date).select { |s| s[:available] },
      }
    end
  end

  private

  def parse_date(value)
    return nil if value.blank?

    value.is_a?(String) ? Date.parse(value) : value
  rescue ArgumentError, TypeError
    nil
  end

  def valid_date?(date)
    date.present? && date >= Date.current
  end

  def business_open?(date)
    return false if date.blank?

    day_name = date.strftime("%A").downcase
    !@business.intervals_for_day(day_name).empty?
  end

  def parse_time(time_str)
    hours, minutes = time_str.split(":").map(&:to_i)
    (hours * 60) + minutes
  end

  def format_time(minutes)
    format("%02d:%02d", minutes / 60, minutes % 60)
  end

  def generate_slots(date, opening_minutes, closing_minutes, existing_bookings)
    slots = []
    current = opening_minutes

    while current + @duration <= closing_minutes
      slot_start = format_time(current)
      slot_end = format_time(current + @duration)

      is_available = !slot_overlaps?(slot_start, slot_end, existing_bookings)

      # Mark past slots as unavailable when the date is today
      if date == Date.current
        slot_time = Time.zone.parse("#{date} #{slot_start}")
        is_available = false if slot_time && slot_time < Time.current
      end

      slots << {
        time: slot_start,
        end_time: slot_end,
        available: is_available,
        duration: @duration,
      }

      current += SLOT_INTERVAL
    end

    slots
  end

  def slot_overlaps?(slot_start, slot_end, existing_bookings)
    existing_bookings.any? do |booking_start, booking_end|
      # Check if the slot overlaps with existing booking
      slot_start < booking_end && slot_end > booking_start
    end
  end
end
