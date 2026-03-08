# frozen_string_literal: true

module Api
  module V1
    module Admin
      class SupportController < BaseController
        def impersonate
          user = User.kept.find(params[:user_id])
          tokens = JwtService.generate_tokens(user, impersonator: current_user)
          set_auth_cookies(tokens)
          log_admin_action(:impersonate, "User", user.id, details: { message: "Impersonated user ##{user.id}" })
          render json: { message: "Impersonating user", access_token: tokens[:access_token],
                         expires_in: tokens[:expires_in] }
        end

        def create_booking
          # Placeholder: create booking on behalf of user
          render json: { message: "Booking created" }
        end

        def activity_log
          scope = AdminActivityLog.recent
            .by_resource_type(params[:resource_type])
            .by_action(params[:action_type])
            .since(params[:since].present? ? Time.zone.parse(params[:since]) : nil)
          scope = scope.includes(:admin_user)
          @pagy, logs = pagy(scope, items: params[:per_page] || 25)
          render json: {
            logs: logs.map { |log| log_entry_json(log) },
            meta: pagination_meta
          }
        end

        private

        def log_entry_json(log)
          {
            id: log.id,
            admin_user_id: log.admin_user_id,
            admin_user_name: log.admin_user&.name || log.admin_user&.email,
            action: log.action,
            resource_type: log.resource_type,
            resource_id: log.resource_id,
            details: log.details,
            created_at: log.created_at&.iso8601
          }
        end

        def set_auth_cookies(tokens)
          cookie_options = { httponly: true, secure: Rails.env.production?,
                             same_site: Rails.env.production? ? :none : :lax }
          cookies[:access_token] =
            { **cookie_options, value: tokens[:access_token], expires: tokens[:expires_in].seconds.from_now }
          cookies[:refresh_token] = { **cookie_options, value: tokens[:refresh_token], expires: 7.days.from_now }
        end
      end
    end
  end
end
