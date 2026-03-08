# frozen_string_literal: true

class AddLatLngToCities < ActiveRecord::Migration[7.1]
  def change
    add_column :cities, :lat, :decimal, precision: 10, scale: 8
    add_column :cities, :lng, :decimal, precision: 11, scale: 8
  end
end
