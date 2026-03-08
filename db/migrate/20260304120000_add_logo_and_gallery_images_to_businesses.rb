# frozen_string_literal: true

class AddLogoAndGalleryImagesToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :logo, :string
    add_column :businesses, :gallery_images, :jsonb, default: []
  end
end
