# frozen_string_literal: true

# Example migration for adding gallery_images JSONB column
# This stores gallery images as JSON with url and public_id
#
# Usage:
# rails generate migration AddGalleryImagesToBusinesses gallery_images:jsonb
#
# Or manually create:

class AddGalleryImagesToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :gallery_images, :jsonb, default: []
    add_index :businesses, :gallery_images, using: :gin
  end
end

# In Business model:
# validates :gallery_images, length: { maximum: 10 }
#
# Structure:
# [
#   { "url": "https://...", "public_id": "businesses/1/uuid" },
#   { "url": "https://...", "public_id": "businesses/1/uuid" }
# ]
