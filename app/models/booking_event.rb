class BookingEvent < ApplicationRecord
  EVENT_TYPES = %w[created confirmed cancelled completed no_show rescheduled].freeze

  belongs_to :booking

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
end

