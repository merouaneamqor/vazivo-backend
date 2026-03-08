# frozen_string_literal: true

module Api
  module V1
    module Provider
      class StatisticsController < ApplicationController
        before_action :authenticate_user!
        before_action :ensure_provider!

        def show
          business = current_user.businesses.find(params[:business_id])
          statistic = business.statistic || BusinessStatistic.create(business: business)

          render json: {
            phone_clicks: statistic.phone_clicks,
            profile_views: statistic.profile_views,
            booking_clicks: statistic.booking_clicks,
            google_maps_clicks: statistic.google_maps_clicks,
            waze_clicks: statistic.waze_clicks,
            updated_at: statistic.updated_at,
          }
        end

        private

        def ensure_provider!
          return if current_user.provider?

          render json: { error: "Unauthorized" }, status: :forbidden
        end
      end
    end
  end
end
