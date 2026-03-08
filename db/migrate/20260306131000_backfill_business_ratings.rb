class BackfillBusinessRatings < ActiveRecord::Migration[7.1]
  class MigrationBusiness < ApplicationRecord
    self.table_name = "businesses"
  end

  class MigrationReview < ApplicationRecord
    self.table_name = "reviews"
  end

  def up
    return unless column_exists?(:businesses, :average_rating) && column_exists?(:businesses, :reviews_count)

    say_with_time "Backfilling average_rating and reviews_count on businesses" do
      MigrationBusiness.find_each do |business|
        scope = MigrationReview.where(business_id: business.id, moderation_status: "approved")
        count = scope.count
        avg = if count.positive?
                scope.average(:rating).to_f.round(1)
              else
                0.0
              end

        business.update_columns(
          average_rating: avg,
          reviews_count: count
        )
      end
    end
  end

  def down
    # Data-only migration
  end
end

