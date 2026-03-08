# frozen_string_literal: true

class AddRestaurantFieldsToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :cuisine_types, :jsonb, default: []
    add_column :businesses, :price_range, :string
    add_column :businesses, :table_capacity, :integer
  end
end
