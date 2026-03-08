class CreateBookings < ActiveRecord::Migration[7.1]
  def change
    create_table :bookings do |t|
      t.references :user, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :business, null: false, foreign_key: true
      t.date :date, null: false
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :bookings, :date
    add_index :bookings, :status
    add_index :bookings, [:service_id, :date, :start_time]
  end
end
