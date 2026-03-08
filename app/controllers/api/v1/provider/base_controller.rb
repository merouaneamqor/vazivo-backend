# frozen_string_literal: true

module Api
  module V1
    module Provider
      class BaseController < ApplicationController
        before_action :authenticate_user!
        before_action :require_provider_confirmed!

        private

        def require_provider_confirmed!
          return unless current_user # Skip if not authenticated
          return if current_user.provider_confirmed?

          render json: { error: "Your provider account is not yet confirmed. Please contact support." },
                 status: :forbidden
        end

        def current_user_businesses
          @current_user_businesses ||= begin
            owned_ids = current_user.businesses.kept.select(:id)
            staff_ids = current_user.business_staff.active.select(:business_id)
            Business.kept.where("id IN (?) OR id IN (?)", owned_ids, staff_ids)
          end
        end
      end
    end
  end
end
