# frozen_string_literal: true

class AddGuestBookingFields < ActiveRecord::Migration[7.1]
  def up
    change_column_null :bookings, :user_id, true

    add_column :bookings, :customer_name, :string
    add_column :bookings, :customer_phone, :string
    add_column :bookings, :customer_email, :string
    add_column :bookings, :short_booking_id, :string

    add_index :bookings, :short_booking_id, unique: true

    # Backfill short_booking_id for existing rows so we can add NOT NULL
    execute <<-SQL.squish
      UPDATE bookings SET short_booking_id = UPPER(SUBSTRING(MD5(id::text || created_at::text) FROM 1 FOR 8))
      WHERE short_booking_id IS NULL
    SQL
    change_column_null :bookings, :short_booking_id, false
  end

  def down
    remove_index :bookings, :short_booking_id, unique: true
    remove_column :bookings, :short_booking_id
    remove_column :bookings, :customer_email
    remove_column :bookings, :customer_phone
    remove_column :bookings, :customer_name
    change_column_null :bookings, :user_id, false
  end
end
