# frozen_string_literal: true

# Example migration for adding CarrierWave photo fields to User model
# Run: rails generate migration AddPhotoToUsers photo_1:string photo_2:string
#
# class AddPhotoToUsers < ActiveRecord::Migration[7.1]
#   def change
#     add_column :users, :photo_1, :string
#     add_column :users, :photo_2, :string
#   end
# end
#
# Then in User model:
# mount_uploader :photo_1, ImageUploader
# mount_uploader :photo_2, ImageUploader
