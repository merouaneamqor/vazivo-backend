# frozen_string_literal: true

module Api
  module V1
    module Admin
      class AuthController < ApplicationController
        # authenticate_user! only for :me (login does not require auth)
        before_action :authenticate_user!, only: [:me]
        before_action :require_admin_role!, only: [:me]

        # POST /api/v1/admin/auth/login — admin-only login (role check; session in HttpOnly cookie)
        def login
          service = AuthService.new
          result = service.login(login_params[:email], login_params[:password])

          return render json: { error: result[:errors].first }, status: :unauthorized unless result[:success]

          user = result[:user]
          unless user.can_access_admin?
            return render json: { error: "Not authorized for admin access" }, status: :forbidden
          end

          set_auth_cookies(result[:tokens])
          render json: {
            message: "Login successful",
            user: UserSerializer.new(user).as_json,
            access_token: result[:tokens][:access_token],
            expires_in: result[:tokens][:expires_in],
          }, status: :ok
        end

        # GET /api/v1/admin/auth/me — current admin user (requires admin role)
        def me
          render json: { user: UserSerializer.new(current_user).as_json }, status: :ok
        end

        private

        def login_params
          params.require(:user).permit(:email, :password)
        end

        def require_admin_role!
          return if current_user&.can_access_admin?

          render json: { error: "Admin access required" }, status: :forbidden
        end

        def set_auth_cookies(tokens)
          cookie_options = {
            httponly: true,
            secure: Rails.env.production? || Rails.env.staging?,
            same_site: Rails.env.production? || Rails.env.staging? ? :none : :lax,
          }

          # Set domain for production/staging to work across subdomains
          if Rails.env.production? || Rails.env.staging?
            domain = ENV["COOKIE_DOMAIN"].presence || extract_root_domain(request.host)
            cookie_options[:domain] = domain if domain
          end

          cookies[:access_token] = {
            **cookie_options,
            value: tokens[:access_token],
            expires: tokens[:expires_in].seconds.from_now,
          }
          cookies[:refresh_token] = {
            **cookie_options,
            value: tokens[:refresh_token],
            expires: 7.days.from_now,
          }
        end

        def extract_root_domain(host)
          parts = host.split(".")
          return nil if parts.length < 2

          ".#{parts[-2..].join('.')}"
        end
      end
    end
  end
end
