# frozen_string_literal: true

module Api
  module V1
    module Public
      class OmniauthCallbacksController < BaseController
        # GET /auth/google_oauth2/callback
        # OmniAuth sets request.env["omniauth.auth"] after exchanging the code.
        def google
          auth = request.env["omniauth.auth"]

          unless auth
            redirect_to_frontend_with_error("Google sign-in failed (no auth data)")
            return
          end

          result = AuthService.new.find_or_create_from_google(auth)

          if result[:success]
            redirect_to_frontend_with_tokens(result[:tokens])
          else
            redirect_to_frontend_with_error(result[:errors]&.first || "Google sign-in failed")
          end
        end

        private

        def redirect_to_frontend_with_tokens(tokens)
          frontend_url = ENV["FRONTEND_URL"].to_s.strip.presence || "http://localhost:3001"

          base = frontend_url
            .sub(/#.*\z/, "") # remove fragment
            .sub(%r{/+\z}, "") # remove trailing slashes

          # Using URL fragment so tokens never hit logs, referer, or backend
          fragment = [
            "access_token=#{ERB::Util.url_encode(tokens[:access_token])}",
            "refresh_token=#{ERB::Util.url_encode(tokens[:refresh_token])}",
            "expires_in=#{tokens[:expires_in]}",
          ].join("&")

          redirect_to "#{base}/auth/callback##{fragment}", allow_other_host: true
        end

        def redirect_to_frontend_with_error(message)
          frontend_url = ENV["FRONTEND_URL"].to_s.strip.presence || "http://localhost:3001"

          base = frontend_url
            .sub(/#.*\z/, "")
            .sub(%r{/+\z}, "")

          redirect_to "#{base}/auth/callback?error=#{ERB::Util.url_encode(message)}",
                      allow_other_host: true
        end
      end
    end
  end
end
