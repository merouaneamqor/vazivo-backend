# frozen_string_literal: true

class AddLocaleColumnsToCategories < ActiveRecord::Migration[7.1]
  def change
    add_column :categories, :name_en, :string
    add_column :categories, :name_fr, :string
    add_column :categories, :name_ar, :string
    add_column :categories, :slug_en, :string
    add_column :categories, :slug_fr, :string
    add_column :categories, :slug_ar, :string

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE categories SET name_en = name, slug_en = slug
          WHERE name_en IS NULL AND name IS NOT NULL
        SQL
      end
    end

    add_index :categories, :slug_en, unique: true, where: "slug_en IS NOT NULL"
    add_index :categories, :slug_fr, unique: true, where: "slug_fr IS NOT NULL"
    add_index :categories, :slug_ar, unique: true, where: "slug_ar IS NOT NULL"
  end
end
