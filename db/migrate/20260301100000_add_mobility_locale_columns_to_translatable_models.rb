# frozen_string_literal: true

class AddMobilityLocaleColumnsToTranslatableModels < ActiveRecord::Migration[7.1]
  def change
    # Businesses: name, description, slug
    add_column :businesses, :name_en, :string
    add_column :businesses, :name_fr, :string
    add_column :businesses, :name_ar, :string
    add_column :businesses, :description_en, :text
    add_column :businesses, :description_fr, :text
    add_column :businesses, :description_ar, :text
    add_column :businesses, :slug_en, :string
    add_column :businesses, :slug_fr, :string
    add_column :businesses, :slug_ar, :string

    # Services: name, description
    add_column :services, :name_en, :string
    add_column :services, :name_fr, :string
    add_column :services, :name_ar, :string
    add_column :services, :description_en, :text
    add_column :services, :description_fr, :text
    add_column :services, :description_ar, :text

    # Plans: name
    add_column :plans, :name_en, :string
    add_column :plans, :name_fr, :string
    add_column :plans, :name_ar, :string

    # Cities: name, slug
    add_column :cities, :name_en, :string
    add_column :cities, :name_fr, :string
    add_column :cities, :name_ar, :string
    add_column :cities, :slug_en, :string
    add_column :cities, :slug_fr, :string
    add_column :cities, :slug_ar, :string

    # Neighborhoods: name, slug
    add_column :neighborhoods, :name_en, :string
    add_column :neighborhoods, :name_fr, :string
    add_column :neighborhoods, :name_ar, :string
    add_column :neighborhoods, :slug_en, :string
    add_column :neighborhoods, :slug_fr, :string
    add_column :neighborhoods, :slug_ar, :string

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE businesses SET name_en = name WHERE name_en IS NULL AND name IS NOT NULL
        SQL
        execute <<-SQL.squish
          UPDATE businesses SET description_en = description WHERE description_en IS NULL AND description IS NOT NULL
        SQL
        execute <<-SQL.squish
          UPDATE businesses SET slug_en = slug WHERE slug_en IS NULL AND slug IS NOT NULL
        SQL
        execute <<-SQL.squish
          UPDATE services SET name_en = name, description_en = description
          WHERE name_en IS NULL AND name IS NOT NULL
        SQL
        execute <<-SQL.squish
          UPDATE plans SET name_en = name WHERE name_en IS NULL AND name IS NOT NULL
        SQL
        execute <<-SQL.squish
          UPDATE cities SET name_en = name, slug_en = slug
          WHERE (name_en IS NULL AND name IS NOT NULL) OR (slug_en IS NULL AND slug IS NOT NULL)
        SQL
        execute <<-SQL.squish
          UPDATE neighborhoods SET name_en = name, slug_en = slug
          WHERE (name_en IS NULL AND name IS NOT NULL) OR (slug_en IS NULL AND slug IS NOT NULL)
        SQL
      end
    end

    add_index :businesses, :slug_en, unique: true, where: "slug_en IS NOT NULL"
    add_index :businesses, :slug_fr, unique: true, where: "slug_fr IS NOT NULL"
    add_index :businesses, :slug_ar, unique: true, where: "slug_ar IS NOT NULL"
    add_index :cities, :slug_en, unique: true, where: "slug_en IS NOT NULL"
    add_index :cities, :slug_fr, unique: true, where: "slug_fr IS NOT NULL"
    add_index :cities, :slug_ar, unique: true, where: "slug_ar IS NOT NULL"
    add_index :neighborhoods, [:city_id, :slug_en], unique: true, name: "index_neighborhoods_on_city_id_and_slug_en", where: "slug_en IS NOT NULL"
    add_index :neighborhoods, [:city_id, :slug_fr], unique: true, name: "index_neighborhoods_on_city_id_and_slug_fr", where: "slug_fr IS NOT NULL"
    add_index :neighborhoods, [:city_id, :slug_ar], unique: true, name: "index_neighborhoods_on_city_id_and_slug_ar", where: "slug_ar IS NOT NULL"
  end
end
