# frozen_string_literal: true

class BookingDetailSerializer < ActiveModel::Serializer
  attributes :id, :date, :start_time, :end_time, :status,
             :total_price, :notes, :special_requests, :number_of_guests,
             :duration_minutes,
             :can_cancel, :can_confirm, :can_complete,
             :confirmed_at, :cancelled_at, :completed_at,
             :created_at, :updated_at

  belongs_to :user, serializer: UserSerializer
  belongs_to :service, serializer: ServiceSerializer
  belongs_to :business, serializer: BusinessSerializer
  has_one :review, serializer: ReviewSerializer

  def start_time
    object.start_time&.strftime("%H:%M")
  end

  def end_time
    object.end_time&.strftime("%H:%M")
  end

  def can_cancel
    object.can_cancel?
  end

  def can_confirm
    object.can_confirm?
  end

  def can_complete
    object.can_complete?
  end

  def special_requests
    object.notes
  end

  def number_of_guests
    object.respond_to?(:number_of_guests) ? object.number_of_guests : nil
  end

  # Primary service for backwards compatibility; derived from first booking_service_item.
  def service
    object.booking_service_items.first&.service
  end
end
