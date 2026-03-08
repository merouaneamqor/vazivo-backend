class AddResponseToReviews < ActiveRecord::Migration[7.1]
  def change
    add_column :reviews, :response, :text
    add_column :reviews, :responded_at, :datetime
    add_index :reviews, :responded_at
  end
end
