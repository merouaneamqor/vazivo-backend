# frozen_string_literal: true

class AddPublishedAtToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :published_at, :datetime, null: true
    add_index :businesses, :published_at, where: "published_at IS NOT NULL"
  end
end
