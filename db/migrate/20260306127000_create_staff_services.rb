class CreateStaffServices < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_services do |t|
      t.bigint :business_id, null: false
      t.bigint :staff_id, null: false
      t.bigint :service_id, null: false
      t.decimal :price_override, precision: 10, scale: 2
      t.integer :duration_override

      t.timestamps
    end

    add_index :staff_services, [:business_id, :staff_id, :service_id], unique: true
    add_index :staff_services, :staff_id
    add_index :staff_services, :service_id

    add_foreign_key :staff_services, :businesses
    add_foreign_key :staff_services, :users, column: :staff_id
    add_foreign_key :staff_services, :services
  end
end

