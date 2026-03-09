# frozen_string_literal: true

class RecalculateBusinessRatingsJob < ApplicationJob
  queue_as :default

  def perform(business_id)
    business = Business.find_by(id: business_id)
    return unless business

    scope = business.reviews.approved
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

    RebuildBusinessSearchIndexJob.perform_later(business.id) if defined?(RebuildBusinessSearchIndexJob)
  end
end
