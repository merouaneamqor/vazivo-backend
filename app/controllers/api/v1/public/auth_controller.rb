# frozen_string_literal: true

module Api
  module V1
    module Public
      class AuthController < BaseController
        before_action :authenticate_user!, only: [:me, :logout, :update_password]

        # GET /api/v1/auth/google — redirects to OmniAuth Google OAuth
        def google_redirect
          base = ENV["BACKEND_URL"].presence || request.base_url
          redirect_to "#{base.sub(%r{/+\z}, '')}/auth/google_oauth2", allow_other_host: true
        end

        # POST /api/v1/auth/register
        def register
          service = AuthService.new
          result = service.register(register_params)

          if result[:success]
            set_auth_cookies(result[:tokens])
            
            # Send welcome email with error handling
            begin
              UserMailer.welcome_customer(result[:user]).deliver_later
            rescue StandardError => e
              Rails.logger.error("Failed to enqueue welcome email for #{result[:user].email}: #{e.message}")
              # Don't fail registration if email fails
            end
            
            discord_notify_new_user(result[:user], "customer")
            render json: {
              message: "Registration successful",
              user: UserSerializer.new(result[:user]).as_json,
              access_token: result[:tokens][:access_token],
              expires_in: result[:tokens][:expires_in],
            }, status: :created
          else
            render_errors(result[:errors])
          end
        end

        # POST /api/v1/auth/register_provider (public: no auth)
        def register_provider
          service = ProviderRegistrationService.new
          result = service.call(
            user_params: register_provider_user_params,
            business_params: register_provider_business_params
          )

          if result[:success]
            set_auth_cookies(result[:tokens])
            
            # Send welcome email with error handling
            begin
              UserMailer.welcome_provider(result[:user], result[:business]).deliver_later
            rescue StandardError => e
              Rails.logger.error("Failed to enqueue welcome email for #{result[:user].email}: #{e.message}")
            end
            
            discord_notify_new_user(result[:user], "provider", result[:business])
            render json: {
              message: "Registration successful",
              user: UserSerializer.new(result[:user]).as_json,
              business: BusinessSerializer.new(result[:business]).as_json,
              access_token: result[:tokens][:access_token],
              expires_in: result[:tokens][:expires_in],
            }, status: :created
          else
            render_errors(result[:errors])
          end
        end

        # POST /api/v1/auth/login
        def login
          service = AuthService.new
          result = service.login(login_params[:email], login_params[:password])

          if result[:success]
            set_auth_cookies(result[:tokens])
            render json: {
              message: "Login successful",
              user: UserSerializer.new(result[:user]).as_json,
              access_token: result[:tokens][:access_token],
              expires_in: result[:tokens][:expires_in],
            }, status: :ok
          else
            render json: { error: result[:errors].first }, status: :unauthorized
          end
        end

        # POST /api/v1/auth/refresh
        def refresh
          refresh_token = cookies[:refresh_token] || params[:refresh_token]

          return render json: { error: "Refresh token required" }, status: :unauthorized unless refresh_token

          service = AuthService.new
          result = service.refresh(refresh_token)

          if result[:success]
            set_auth_cookies(result[:tokens])
            render json: {
              access_token: result[:tokens][:access_token],
              expires_in: result[:tokens][:expires_in],
            }, status: :ok
          else
            clear_auth_cookies
            render json: { error: result[:errors].first }, status: :unauthorized
          end
        end

        # DELETE /api/v1/auth/logout
        def logout
          clear_auth_cookies
          render json: { message: "Logged out successfully" }, status: :ok
        end

        # GET /api/v1/auth/me
        def me
          render json: { user: UserSerializer.new(current_user).as_json }, status: :ok
        end

        # PATCH /api/v1/auth/password
        def update_password
          service = AuthService.new
          result = service.update_password(
            current_user,
            password_params[:current_password],
            password_params[:new_password],
            password_params[:new_password_confirmation]
          )

          if result[:success]
            render json: { message: "Password updated successfully" }, status: :ok
          else
            render_errors(result[:errors])
          end
        end

        # POST /api/v1/auth/forgot_password
        def forgot_password
          service = AuthService.new
          result = service.request_password_reset(params[:email])

          render json: { message: result[:message] }, status: :ok
        end

        # GET /api/v1/auth/validate_reset_token
        def validate_reset_token
          service = AuthService.new
          result = service.validate_reset_token(params[:token], params[:email])

          if result[:valid]
            render json: { status: "ok" }, status: :ok
          else
            render json: { status: "invalid", error: result[:error] }, status: :unprocessable_entity
          end
        end

        # POST /api/v1/auth/reset_password
        def reset_password
          service = AuthService.new
          result = service.reset_password(
            params[:token],
            params[:email],
            params[:password]
          )

          if result[:success]
            render json: { status: "success", message: result[:message] }, status: :ok
          else
            render json: { status: "error", error: result[:errors]&.first || "Failed to reset password" }, status: :unprocessable_entity
          end
        end

        private

        def register_params
          params.require(:user).permit(:first_name, :last_name, :name, :email, :phone, :password, :password_confirmation, :role)
        end

        def register_provider_user_params
          params.require(:user).permit(:first_name, :last_name, :name, :email, :phone, :password, :password_confirmation)
        end

        def register_provider_business_params
          params.require(:business).permit(
            :name, :description, :category, :address, :city, :country, :neighborhood, :phone, :email, :website,
            opening_hours: {},
            categories: []
          )
        end

        def login_params
          params.require(:user).permit(:email, :password)
        end

        def password_params
          params.require(:user).permit(:current_password, :new_password, :new_password_confirmation)
        end

        def discord_notify_new_user(user, role, business = nil)
          fields = [
            { name: "Email", value: user.email, inline: true },
            { name: "Name", value: user.name, inline: true },
            { name: "Role", value: role, inline: true },
          ]
          fields << { name: "Business", value: business.translated_name, inline: false } if business
          DiscordNotifier.notify_embed(
            title: "New signup",
            description: role == "provider" ? "A new provider registered with a business." : "A new customer signed up.",
            fields: fields,
            color: 0x5865f2 # Discord blurple
          )
        end

        def set_auth_cookies(tokens)
          # Cross-origin (e.g. Vercel frontend → Railway backend) requires SameSite=None; Secure
          cookie_options = {
            httponly: true,
            secure: Rails.env.production? || Rails.env.staging?,
            same_site: Rails.env.production? || Rails.env.staging? ? :none : :lax,
            expires: nil, # set per-cookie below
          }
          
          # Set domain for production/staging to work across subdomains
          if Rails.env.production? || Rails.env.staging?
            domain = ENV["COOKIE_DOMAIN"].presence || extract_root_domain(request.host)
            cookie_options[:domain] = domain if domain
          end

          # Access token cookie (short-lived) - plain cookie so frontend middleware can read JWT
          cookies[:access_token] = {
            **cookie_options.except(:expires),
            value: tokens[:access_token],
            expires: tokens[:expires_in].seconds.from_now,
          }

          # Refresh token cookie (long-lived) - plain cookie for consistency
          cookies[:refresh_token] = {
            **cookie_options.except(:expires),
            value: tokens[:refresh_token],
            expires: 7.days.from_now,
          }
        end
        
        def extract_root_domain(host)
          # Extract root domain (e.g., "vazivo.com" from "infra.vazivo.com")
          parts = host.split(".")
          return nil if parts.length < 2
          ".#{parts[-2..-1].join('.')}"
        end

        def clear_auth_cookies
          delete_options = {}
          
          # Must use same domain as when setting cookies
          if Rails.env.production? || Rails.env.staging?
            domain = ENV["COOKIE_DOMAIN"].presence || extract_root_domain(request.host)
            delete_options[:domain] = domain if domain
          end
          
          cookies.delete(:access_token, delete_options)
          cookies.delete(:refresh_token, delete_options)
        end
      end
    end
  end
end
