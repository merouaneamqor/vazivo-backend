# frozen_string_literal: true

module Api
  module V1
    class AccountController < ApplicationController
      before_action :authenticate_user!

      # GET /api/v1/account/profile
      def profile
        render json: { user: UserSerializer.new(current_user).as_json }, status: :ok
      end

      # PATCH /api/v1/account/profile
      def update_profile
        if current_user.update(profile_params)
          render json: { user: UserSerializer.new(current_user).as_json }, status: :ok
        else
          render_errors(current_user.errors.full_messages, :unprocessable_entity)
        end
      end

      private

      def profile_params
        params.require(:user).permit(:locale)
      end
    end
  end
end
