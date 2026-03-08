class AddStaffBookingConflictIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :bookings, [:staff_id, :date, :start_time], name: "index_bookings_on_staff_id_and_date_and_start_time"

    add_index :bookings,
              [:staff_id, :date, :start_time],
              where: "status IN ('pending','confirmed')",
              name: "index_bookings_on_staff_date_start_time_active"
  end
end

