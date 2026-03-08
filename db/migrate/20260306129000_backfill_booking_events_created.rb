class BackfillBookingEventsCreated < ActiveRecord::Migration[7.1]
  class MigrationBooking < ApplicationRecord
    self.table_name = "bookings"
  end

  class MigrationBookingEvent < ApplicationRecord
    self.table_name = "booking_events"
  end

  def up
    return unless table_exists?(:booking_events)

    say_with_time "Backfilling booking_events 'created' for existing bookings" do
      MigrationBooking.find_each do |booking|
        next if MigrationBookingEvent.exists?(booking_id: booking.id, event_type: "created")

        MigrationBookingEvent.create!(
          booking_id: booking.id,
          event_type: "created",
          metadata: {},
          created_at: booking.created_at || Time.current
        )
      end
    end
  end

  def down
    # Data-only migration
  end
end

