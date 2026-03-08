class RemoveServiceFromBookings < ActiveRecord::Migration[7.1]
  def change
    if index_exists?(:bookings, [:service_id, :date, :start_time], name: "index_bookings_on_service_id_and_date_and_start_time")
      remove_index :bookings, name: "index_bookings_on_service_id_and_date_and_start_time"
    end

    if index_exists?(:bookings, :service_id)
      remove_index :bookings, :service_id
    end

    if foreign_key_exists?(:bookings, :services)
      remove_foreign_key :bookings, :services
    end

    if column_exists?(:bookings, :service_id)
      remove_column :bookings, :service_id, :bigint
    end
  end
end

