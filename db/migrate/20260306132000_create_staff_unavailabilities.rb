class CreateStaffUnavailabilities < ActiveRecord::Migration[7.1]
  def change
    create_table :staff_unavailabilities do |t|
      t.bigint :business_id, null: false
      t.bigint :user_id, null: false
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :reason

      t.timestamps
    end

    add_index :staff_unavailabilities, [:business_id, :user_id, :start_time]
    add_index :staff_unavailabilities, :user_id

    add_foreign_key :staff_unavailabilities, :businesses
    add_foreign_key :staff_unavailabilities, :users
  end
end

