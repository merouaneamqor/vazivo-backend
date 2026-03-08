# frozen_string_literal: true

class AddNeighborhoodAndCategoriesToBusinesses < ActiveRecord::Migration[7.1]
  def up
    add_column :businesses, :neighborhood, :string
    add_column :businesses, :categories, :jsonb, default: []

    # Backfill: set categories = [category] for existing businesses
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE businesses
          SET categories = jsonb_build_array(category)
          WHERE category IS NOT NULL AND category != '' AND (
            categories = '[]'::jsonb OR jsonb_array_length(categories) = 0
          )
        SQL
      end
    end
  end

  def down
    remove_column :businesses, :neighborhood
    remove_column :businesses, :categories
  end
end
