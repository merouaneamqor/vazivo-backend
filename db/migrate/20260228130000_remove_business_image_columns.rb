# frozen_string_literal: true

class RemoveBusinessImageColumns < ActiveRecord::Migration[7.1]
  def up
    remove_column :businesses, :cover_image_url, :string if column_exists?(:businesses, :cover_image_url)
    remove_column :businesses, :gallery_urls, :jsonb if column_exists?(:businesses, :gallery_urls)
    remove_column :businesses, :logo_url, :string if column_exists?(:businesses, :logo_url)
  end

  def down
    add_column :businesses, :cover_image_url, :string unless column_exists?(:businesses, :cover_image_url)
    add_column :businesses, :gallery_urls, :jsonb, default: [] unless column_exists?(:businesses, :gallery_urls)
    add_column :businesses, :logo_url, :string unless column_exists?(:businesses, :logo_url)
  end
end
