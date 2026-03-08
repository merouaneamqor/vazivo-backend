# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.references :parent, null: true, foreign_key: { to_table: :categories }
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :categories, :slug, unique: true
  end
end
