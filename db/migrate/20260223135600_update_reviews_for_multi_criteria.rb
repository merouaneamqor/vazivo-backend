# frozen_string_literal: true

class UpdateReviewsForMultiCriteria < ActiveRecord::Migration[7.1]
  def change
    # Add multi-criteria ratings
    add_column :reviews, :cleanliness_rating, :integer
    add_column :reviews, :punctuality_rating, :integer
    add_column :reviews, :professionalism_rating, :integer
    add_column :reviews, :service_quality_rating, :integer
    add_column :reviews, :hygiene_rating, :integer
    
    # Premium-only categories
    add_column :reviews, :ambiance_rating, :integer
    add_column :reviews, :staff_friendliness_rating, :integer
    add_column :reviews, :waiting_time_rating, :integer
    add_column :reviews, :value_rating, :integer
    
    # Photo storage
    add_column :reviews, :photos, :jsonb, default: []
    
    # Metadata
    add_column :reviews, :edited_at, :datetime
    add_column :reviews, :moderation_status, :string, default: 'approved'
    add_column :reviews, :moderation_notes, :text
    
    # Backfill existing reviews
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE reviews 
          SET 
            cleanliness_rating = rating,
            punctuality_rating = rating,
            professionalism_rating = rating,
            service_quality_rating = rating,
            hygiene_rating = rating
          WHERE cleanliness_rating IS NULL
        SQL
      end
    end
    
    # Add indexes
    add_index :reviews, :moderation_status
    add_index :reviews, [:business_id, :moderation_status]
  end
end
