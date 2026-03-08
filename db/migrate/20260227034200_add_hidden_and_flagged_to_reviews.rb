class AddHiddenAndFlaggedToReviews < ActiveRecord::Migration[7.1]
  def change
    add_column :reviews, :hidden_at, :datetime
    add_column :reviews, :flagged_at, :datetime
    add_column :reviews, :flag_reason, :text
  end
end
