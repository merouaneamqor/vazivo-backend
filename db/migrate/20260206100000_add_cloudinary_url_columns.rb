# frozen_string_literal: true

class AddCloudinaryUrlColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :cover_image_url, :string
    add_column :businesses, :gallery_urls, :jsonb, default: []
    add_column :services, :image_url, :string
  end
end
