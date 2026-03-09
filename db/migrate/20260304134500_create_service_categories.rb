# frozen_string_literal: true

class CreateServiceCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :service_categories do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :color, default: '#3B82F6'
      t.integer :position, default: 0, null: false
      t.datetime :archived_at

      t.timestamps
    end

    add_index :service_categories, :archived_at
    add_index :service_categories, [:business_id, :position]

    # Add service_category_id to services table
    add_reference :services, :service_category, foreign_key: true
  end
end
