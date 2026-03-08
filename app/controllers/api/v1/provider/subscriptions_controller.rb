# frozen_string_literal: true

module Api
  module V1
    module Provider
      class SubscriptionsController < ApplicationController
        before_action :authenticate_user!
        before_action :require_provider_confirmed!

        # GET /api/v1/provider/subscription
        # Returns per-business premium and subscription (user has access if any business is premium)
        def show
          businesses_data = current_user.businesses.kept.map do |b|
            sub = b.current_subscription
            {
              id: b.id,
              name: b.translated_name,
              premium: b.premium?,
              premium_expires_at: b.premium_expires_at,
              subscription: sub ? serialize_subscription(sub) : nil,
            }
          end

          render json: {
            premium: current_user.premium?,
            businesses: businesses_data,
          }
        end

        private

        def require_provider_confirmed!
          return if current_user.provider_confirmed?

          render json: { error: "Provider account not confirmed" }, status: :forbidden
        end

        def serialize_subscription(sub)
          {
            id: sub.id,
            status: sub.status,
            plan_id: sub.plan_id,
            paid_via: sub.paid_via,
            started_at: sub.started_at,
            expires_at: sub.expires_at,
            active: sub.active?,
          }
        end
      end
    end
  end
end
