class BackfillBookingServicesFromBookings < ActiveRecord::Migration[7.1]
  class MigrationBooking < ApplicationRecord
    self.table_name = "bookings"
  end

  class MigrationBookingServiceItem < ApplicationRecord
    self.table_name = "booking_services"
  end

  class MigrationService < ApplicationRecord
    self.table_name = "services"
  end

  def up
    say_with_time "Backfilling booking_services from existing bookings.service_id" do
      MigrationBooking.find_each do |booking|
        next if booking.service_id.nil?
        next if MigrationBookingServiceItem.exists?(booking_id: booking.id)

        service = MigrationService.find_by(id: booking.service_id)
        next unless service

        price = booking.total_price.presence || service.price
        duration = service.duration

        MigrationBookingServiceItem.create!(
          booking_id: booking.id,
          service_id: service.id,
          staff_id: booking.staff_id,
          price: price,
          duration_minutes: duration,
          position: 0
        )
      end
    end
  end

  def down
    # No-op: data migration only
  end
end

