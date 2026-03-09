# frozen_string_literal: true

class RebuildBusinessSearchIndexJob < ApplicationJob
  queue_as :default

  def perform(business_id)
    business = Business.find_by(id: business_id)
    return unless business

    first_name = business.read_attribute(:category).presence || Array(business.read_attribute(:categories)).first
    primary_category_id = if first_name.present?
                            Category.find_by(name: first_name)&.id || Category.where("LOWER(name) = ?",
                                                                                     first_name.to_s.downcase).first&.id
                          end

    index = BusinessSearchIndex.find_or_initialize_by(business_id: business.id)
    index.city_id = business.city_id
    index.category_id = primary_category_id
    index.rating = business.average_rating
    index.reviews_count = business.total_reviews
    index.lat = business.lat
    index.lng = business.lng
    index.h3_index = business.h3_index
    index.save!
  end
end
