# frozen_string_literal: true

class Booking < ApplicationRecord
  # Associations
  belongs_to :user, optional: true # Customer who booked (nil for walk-ins)
  belongs_to :staff, class_name: "User", optional: true # Provider/staff assigned to this booking (legacy)
  belongs_to :business
  has_one :review, dependent: :destroy
  has_one :booking_payment, dependent: :destroy
  has_many :booking_service_items, class_name: 'BookingServiceItem', foreign_key: 'booking_id', dependent: :destroy
  has_many :services, through: :booking_service_items
  has_many :booking_events, dependent: :destroy

  # Validations
  validates :date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, inclusion: { in: ["pending", "confirmed", "cancelled", "completed", "no_show"] }
  validates :total_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :number_of_guests, numericality: { greater_than: 0, less_than_or_equal_to: 50 }, allow_nil: true
  validate :guest_fields_required_when_no_user
  validate :end_time_after_start_time
  validate :no_overlapping_bookings, on: :create
  validate :booking_within_business_hours, on: :create
  validate :booking_in_future, on: :create

  # When true (e.g. provider confirms), skip business hours validation
  attr_accessor :skip_business_hours_check

  # Callbacks
  before_validation :normalize_customer_phone
  before_validation :generate_short_booking_id, on: :create

  accepts_nested_attributes_for :booking_service_items

  # Enums
  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    cancelled: "cancelled",
    completed: "completed",
    no_show: "no_show",
  }, prefix: true

  # Scopes
  scope :upcoming, -> { where(date: Date.current..).where.not(status: [:cancelled, :no_show]) }
  scope :past, -> { where(date: ...Date.current) }
  scope :for_business, ->(business_id) { where(business_id: business_id) }
  scope :for_staff, ->(staff_id) { where(staff_id: staff_id) }
  scope :for_date, ->(date) { where(date: date) }
  scope :for_date_range, ->(start_date, end_date) { where(date: start_date..end_date) }
  scope :active, -> { where.not(status: [:cancelled, :no_show]) }
  scope :for_guest_lookup, ->(email: nil, phone: nil) {
    rel = where(user_id: nil)
    normalized = normalize_phone_for_lookup(phone)
    conds = []
    conds << "customer_email ILIKE ?" if email.present?
    if normalized.present?
      conds << "REPLACE(REPLACE(REPLACE(COALESCE(customer_phone,''), ' ', ''), '-', ''), '+', '') = ?"
    end
    return rel.none if conds.empty?

    if email.present? && normalized.present?
      rel.where("(customer_email ILIKE ?) OR (REPLACE(REPLACE(REPLACE(COALESCE(customer_phone,''), ' ', ''), '-', ''), '+', '') = ?)", email, normalized)
    elsif email.present?
      rel.where("customer_email ILIKE ?", email)
    else
      rel.where("REPLACE(REPLACE(REPLACE(COALESCE(customer_phone,''), ' ', ''), '-', ''), '+', '') = ?", normalized)
    end
  }

  class << self
    def normalize_phone_for_lookup(phone)
      return nil if phone.blank?

      phone.to_s.gsub(/\s|-|\+/, "")
    end
  end

  # Methods
  def customer_phone_normalized
    self.class.normalize_phone_for_lookup(customer_phone)
  end

  def can_cancel?
    (status_pending? || status_confirmed?) && date >= Date.current
  end

  def can_confirm?
    status_pending?
  end

  def can_complete?
    status_confirmed? && date <= Date.current
  end

  def cancel!
    return false unless can_cancel?

    update(status: :cancelled, cancelled_at: Time.current)
  end

  def confirm!
    return false unless can_confirm?

    update(status: :confirmed, confirmed_at: Time.current)
  end

  def complete!
    return false unless can_complete?

    update(status: :completed, completed_at: Time.current)
  end

  def duration_minutes
    return 0 unless start_time && end_time

    ((end_time - start_time) / 60).to_i
  end

  def customer_display_name
    user&.name || customer_name || "Guest"
  end

  private

  def guest_fields_required_when_no_user
    return if user_id.present?

    errors.add(:customer_name, "can't be blank") if customer_name.blank?
    errors.add(:customer_phone, "can't be blank") if customer_phone.blank?
  end

  def normalize_customer_phone
    return if customer_phone.blank?

    self.customer_phone = customer_phone.to_s.gsub(/\s+/, " ").strip
  end

  def generate_short_booking_id
    return if short_booking_id.present?

    loop do
      self.short_booking_id = SecureRandom.hex(4).upcase
      break unless Booking.exists?(short_booking_id: short_booking_id)
    end
  end

  def end_time_after_start_time
    return if end_time.blank? || start_time.blank?

    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end

  def no_overlapping_bookings
    return if date.blank? || start_time.blank? || end_time.blank?

    scope = Booking.active.where(date: date)

    if staff_id.present?
      scope = scope.where(staff_id: staff_id)
    elsif business_id.present?
      scope = scope.where(business_id: business_id)
    else
      return
    end

    overlapping = scope.where("start_time < ? AND end_time > ?", end_time, start_time)
    overlapping = overlapping.where.not(id: id) if persisted?

    errors.add(:base, "This time slot is already booked") if overlapping.exists?
  end

  def booking_within_business_hours
    return if skip_business_hours_check
    return if business.blank? || date.blank? || start_time.blank?

    day = date.strftime("%A").downcase
    intervals = business.intervals_for_day(day)

    if intervals.empty?
      errors.add(:base, "Business is closed on this day")
      return
    end

    start_str = start_time.strftime("%H:%M")
    end_str = end_time&.strftime("%H:%M")

    within_any = intervals.any? do |int|
      start_ok = start_str >= int["open"]
      end_ok = end_str.blank? || end_str <= int["close"]
      start_ok && end_ok
    end

    errors.add(:base, "Booking time is outside business hours") unless within_any
  end

  def booking_in_future
    return if date.blank?

    errors.add(:date, "must be in the future") if date < Date.current
  end

  # Business, end_time and total_price are derived in BookingService
end
