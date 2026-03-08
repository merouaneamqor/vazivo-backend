class CreateBookingEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :booking_events do |t|
      t.bigint :booking_id, null: false
      t.string :event_type, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :booking_events, [:booking_id, :created_at]
    add_foreign_key :booking_events, :bookings
  end
end

