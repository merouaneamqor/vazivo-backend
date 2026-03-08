class CreateBookingServices < ActiveRecord::Migration[7.1]
  def change
    create_table :booking_services do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :staff, foreign_key: { to_table: :users }
      t.decimal :price, precision: 10, scale: 2
      t.integer :duration_minutes
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :booking_services, [:booking_id, :service_id], unique: true
  end
end
