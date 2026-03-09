# frozen_string_literal: true

class BookingSerializer < ActiveModel::Serializer
  attributes :id, :date, :start_time, :end_time, :status,
             :total_price, :notes, :special_requests, :number_of_guests,
             :duration_minutes,
             :can_cancel, :can_confirm, :can_complete,
             :service_id, :service_name, :business_id, :business_name, :business_slug,
             :user, :short_booking_id,
             :customer_name, :customer_phone, :customer_email,
             :staff_id, :staff,
             :booking_services,
             :created_at

  def start_time
    object.start_time&.strftime("%H:%M")
  end

  def end_time
    object.end_time&.strftime("%H:%M")
  end

  def user
    return nil unless object.user

    {
      id: object.user.id,
      name: object.user.name,
      email: object.user.email,
      phone: object.user.phone,
    }
  end

  def can_cancel
    object.can_cancel?
  end

  def special_requests
    object.notes
  end

  def number_of_guests
    object.respond_to?(:number_of_guests) ? object.number_of_guests : nil
  end

  def can_confirm
    object.can_confirm?
  end

  def can_complete
    object.can_complete?
  end

  def service_id
    object.booking_service_items.first&.service_id
  end

  def service_name
    object.booking_service_items.first&.service&.translated_name || "Unknown Service"
  end

  def business_name
    object.business&.translated_name || "Unknown Business"
  end

  def business_slug
    object.business&.translated_slug
  end

  # Use display name so guest bookings (user_id nil) show customer_name; logged-in users show user name
  def customer_name
    object.customer_display_name
  end

  delegate :staff_id, to: :object

  def staff
    return nil unless object.staff

    {
      id: object.staff.id,
      name: object.staff.name,
      email: object.staff.email,
    }
  end

  def booking_services
    object.booking_service_items.map do |bs|
      {
        id: bs.id,
        service_id: bs.service_id,
        service_name: bs.service&.translated_name,
        staff_id: bs.staff_id,
        staff_name: bs.staff&.name,
        price: bs.price,
        duration_minutes: bs.duration_minutes,
        position: bs.position,
      }
    end
  end
end
