# frozen_string_literal: true

class BusinessStatistic < ApplicationRecord
  belongs_to :business

  validates :phone_clicks, :profile_views, :booking_clicks, :google_maps_clicks, :waze_clicks,
            numericality: { greater_than_or_equal_to: 0 }

  def self.increment_phone_clicks(business_id)
    stat = find_or_create_by(business_id: business_id)
    stat.increment!(:phone_clicks)
  end

  def self.increment_profile_views(business_id)
    stat = find_or_create_by(business_id: business_id)
    stat.increment!(:profile_views)
  end

  def self.increment_booking_clicks(business_id)
    stat = find_or_create_by(business_id: business_id)
    stat.increment!(:booking_clicks)
  end

  def self.increment_google_maps_clicks(business_id)
    stat = find_or_create_by(business_id: business_id)
    stat.increment!(:google_maps_clicks)
  end

  def self.increment_waze_clicks(business_id)
    stat = find_or_create_by(business_id: business_id)
    stat.increment!(:waze_clicks)
  end
end
