# frozen_string_literal: true

class CreatePlans < ActiveRecord::Migration[7.1]
  def change
    create_table :plans do |t|
      t.string :name, null: false
      t.string :identifier, null: false
      t.integer :duration_months, null: false
      t.decimal :suggested_price, precision: 12, scale: 2
      t.string :currency, default: "mad", null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :plans, :identifier, unique: true
    add_index :plans, :active
  end
end
