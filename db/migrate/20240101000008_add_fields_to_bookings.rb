class AddFieldsToBookings < ActiveRecord::Migration[7.1]
  def change
    add_column :bookings, :total_price, :decimal, precision: 10, scale: 2
    add_column :bookings, :notes, :text
    add_column :bookings, :confirmed_at, :datetime
    add_column :bookings, :cancelled_at, :datetime
    add_column :bookings, :completed_at, :datetime

    add_index :bookings, :confirmed_at
    add_index :bookings, :cancelled_at
  end
end
