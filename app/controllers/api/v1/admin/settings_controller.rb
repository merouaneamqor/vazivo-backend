# frozen_string_literal: true

module Api
  module V1
    module Admin
      class SettingsController < BaseController
        def show
          render json: {
            maintenance_mode: false,
            cors_origins: ENV.fetch("CORS_ORIGINS", nil),
            frontend_url: ENV.fetch("FRONTEND_URL", nil),
          }
        end

        def update
          # Placeholder: persist in Redis or DB
          log_admin_action(:update, "Settings", nil, details: { message: "Updated settings" })
          render json: { message: "Settings updated" }
        end
      end
    end
  end
end
