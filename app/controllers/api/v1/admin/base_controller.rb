# frozen_string_literal: true

module Api
  module V1
    module Admin
      class BaseController < ApplicationController
        include ::AdminActivityLoggable

        before_action :authenticate_user!
        before_action :require_admin_role!

        private

        def require_admin_role!
          return if current_user&.can_access_admin?

          render json: { error: "Admin access required" }, status: :forbidden
        end
      end
    end
  end
end
