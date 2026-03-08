# frozen_string_literal: true

class AddStaffToBookingsAndCreateBusinessStaff < ActiveRecord::Migration[7.1]
  def change
    # Add staff_id to bookings (the provider/staff member assigned to this booking)
    add_reference :bookings, :staff, foreign_key: { to_table: :users }, null: true, index: true

    # Business staff join table: providers assigned to work at a business
    create_table :business_staffs do |t|
      t.references :business, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, default: 'staff' # e.g. 'owner', 'staff', 'manager'
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :business_staffs, [:business_id, :user_id], unique: true

    # Staff availabilities: each staff member's availability per business
    create_table :staff_availabilities do |t|
      t.references :business, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :day_of_week, null: false # 0 = Sunday, 1 = Monday, etc.
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.boolean :available, default: true
      t.timestamps
    end

    add_index :staff_availabilities, [:business_id, :user_id, :day_of_week],
              name: 'index_staff_availabilities_unique',
              unique: true

    # Backfill existing bookings: set staff_id to the business owner
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE bookings
          SET staff_id = businesses.user_id
          FROM businesses
          WHERE bookings.business_id = businesses.id
            AND bookings.staff_id IS NULL
        SQL
      end
    end

    # Backfill business_staffs: add business owner as staff with 'owner' role
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO business_staffs (business_id, user_id, role, active, created_at, updated_at)
          SELECT id, user_id, 'owner', true, NOW(), NOW()
          FROM businesses
          WHERE discarded_at IS NULL
          ON CONFLICT (business_id, user_id) DO NOTHING
        SQL
      end
    end
  end
end
