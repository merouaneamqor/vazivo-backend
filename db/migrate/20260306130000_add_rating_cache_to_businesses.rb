class AddRatingCacheToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :average_rating, :float, null: false, default: 0.0
    add_column :businesses, :reviews_count, :integer, null: false, default: 0
  end
end

