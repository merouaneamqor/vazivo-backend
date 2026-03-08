# frozen_string_literal: true

module Api
  module V1
    module User
      class UpgradeController < ApplicationController
        before_action :authenticate_user!
        before_action :ensure_customer_role
        before_action :ensure_no_existing_business

        def create
          service = ProviderUpgradeService.new(current_user)
          result = service.call(business_params: upgrade_params)

          if result[:success]
            set_auth_cookies(result[:tokens])

            render json: {
              message: "Upgraded to provider successfully",
              user: UserSerializer.new(result[:user]).as_json,
              business: BusinessSerializer.new(result[:business]).as_json,
              access_token: result[:tokens][:access_token],
              expires_in: result[:tokens][:expires_in],
            }, status: :ok
          else
            render_errors(result[:errors])
          end
        end

        private

        def ensure_customer_role
          return if current_user.role_customer?

          render json: { error: "Only customers can upgrade to provider" }, status: :forbidden
        end

        def ensure_no_existing_business
          return unless current_user.businesses.exists?

          render json: { error: "You already have a business" }, status: :unprocessable_entity
        end

        def upgrade_params
          params.require(:business).permit(
            :name, :description, :category, :address, :city, :country,
            :neighborhood, :phone, :email, :website,
            categories: []
          )
        end

        def set_auth_cookies(tokens)
          cookie_options = {
            httponly: true,
            secure: Rails.env.production? || Rails.env.staging?,
            same_site: Rails.env.production? || Rails.env.staging? ? :none : :lax,
            expires: nil,
          }

          cookies[:access_token] = {
            **cookie_options.except(:expires),
            value: tokens[:access_token],
            expires: tokens[:expires_in].seconds.from_now,
          }

          cookies[:refresh_token] = {
            **cookie_options.except(:expires),
            value: tokens[:refresh_token],
            expires: 7.days.from_now,
          }
        end
      end
    end
  end
end
