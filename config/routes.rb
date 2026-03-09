# frozen_string_literal: true

require "sidekiq/web"
# require "sidekiq/cron/web"

Rails.application.routes.draw do
  devise_for :users, skip: :all

  # Google OAuth callback
  get "/auth/google_oauth2/callback", to: "api/v1/public/omniauth_callbacks#google"

  # Letter Opener (development)
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if defined?(LetterOpenerWeb)

  # Sidekiq Web UI
  if defined?(Sidekiq::Web)
    if ENV["SIDEKIQ_WEB_PASSWORD"].present?
      Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
        [user, password] == [ENV["SIDEKIQ_WEB_USER"].presence || "admin", ENV["SIDEKIQ_WEB_PASSWORD"]]
      end
    end
    mount Sidekiq::Web, at: "/sidekiq"
  end

  # Health check
  get "health", to: "health#index"

  namespace :api do
    namespace :v1 do
      # ==========================================
      # PUBLIC NAMESPACE (No authentication)
      # ==========================================
      namespace :public do
        # Authentication
        scope path: "auth", controller: "auth" do
          get "google", action: :google_redirect
          post "register"
          post "register_provider"
          post "login"
          post "refresh"
          delete "logout"
          get "me"
          patch "password"
          post "forgot_password"
          get "validate_reset_token"
          post "reset_password"
        end

        # Businesses (public view)
        resources :businesses, param: :slug, only: [:index, :show] do
          collection do
            get :search
            get :featured
            get :nearby
          end
          member do
            get :services
            get :reviews
            get :availability
            post :claim
          end
        end

        # Tracking endpoints
        post "businesses/:id/track-phone-click", to: "businesses#track_phone_click"
        post "businesses/:id/track-profile-view", to: "businesses#track_profile_view"
        post "businesses/:id/track-booking-click", to: "businesses#track_booking_click"
        post "businesses/:id/track-google-maps-click", to: "businesses#track_google_maps_click"
        post "businesses/:id/track-waze-click", to: "businesses#track_waze_click"

        # Bookings (public confirmation)
        get "bookings/:short_booking_id", to: "bookings#show"

        # Public service by id (for booking flow; same models as provider)
        resources :services, only: [:show], param: :id do
          get :availability, on: :member
        end

        # Search metadata
        scope path: "search_metadata", controller: "search_metadata" do
          get "cities"
          get "categories"
          get "categories_hierarchy"
          get "filters"
        end

        # SEO page overrides (admin-managed title/description/seo_text per path)
        get "seo_pages", to: "seo_pages#show"

        # Webhooks
        post "webhooks/stripe", to: "webhooks#stripe"
      end

      # Public review creation (QR code) - outside public namespace to access customer controller
      post "public/reviews/public", to: "customer/reviews#create_public"

      # ==========================================
      # USER NAMESPACE (Authenticated users)
      # ==========================================
      namespace :user do
        post "upgrade-to-provider", to: "upgrade#create"
      end

      # ==========================================
      # CUSTOMER NAMESPACE (Authenticated customers)
      # ==========================================
      namespace :customer do
        resources :bookings do
          member do
            post :confirm
            post :cancel
            post :complete
          end
        end

        resources :reviews, only: [:show, :create, :update, :destroy]

        scope path: "booking_payments", controller: "booking_payments" do
          post "create_intent"
        end
      end

      # ==========================================
      # PROVIDER NAMESPACE (Authenticated providers)
      # ==========================================
      namespace :provider do
        # Dashboard
        get "dashboard", to: "dashboard#index"
        get "stats", to: "dashboard#stats"
        get "bookings", to: "dashboard#bookings"
        get "calendar", to: "dashboard#calendar"

        resources :businesses do
          collection do
            get :search
          end
          member do
            get :bookings
            get :stats
            get :staff
            post "staff", action: :invite_staff
            post "staff/:user_id", action: :add_staff
            patch "staff/:user_id", action: :update_staff
            delete "staff/:user_id", action: :remove_staff
            get :availabilities
            post :photos, action: :add_photos
            delete :photos, action: :remove_photo
          end
          resources :services, only: [:index, :create]
          resources :reviews, only: [:index]
          resources :clients, only: [:index, :create, :show, :update]
          resources :images, only: [:create, :destroy]
          resources :service_categories do
            member do
              post :archive
              post :unarchive
              post :generate_description
            end
            collection do
              post :reorder
            end
          end
        end

        resources :services, only: [:show, :update, :destroy] do
          member do
            get :availability
          end
        end

        scope path: "uploads", controller: "uploads" do
          post "image"
          post "cloudinary-sign", action: :cloudinary_sign
        end

        get "search", to: "search#index"
        get "subscription", to: "subscriptions#show"

        resources :reviews, only: [:index] do
          member do
            post :respond
            post :moderate
          end
        end

        get "statistics/:business_id", to: "statistics#show"
      end

      # ==========================================
      # ADMIN NAMESPACE (Authenticated admins)
      # ==========================================
      namespace :admin do
        scope path: "auth", controller: "auth" do
          post "login"
          get "me"
        end

        post "exit_impersonation", to: "providers#exit_impersonation"

        get "dashboard", to: "dashboard#index"

        resources :users, only: [:index, :show, :update, :destroy] do
          member do
            post :suspend
            post :unsuspend
            post :force_password_reset
          end
        end

        resources :providers, only: [:index, :show, :create, :update] do
          member do
            post :approve
            post :unconfirm
            post :reject
            post :suspend
            post :impersonate
            post :verify
            post :unverify
            post :reactivate
            post :send_onboarding_email
            post :upgrade
          end
        end

        resources :bookings, only: [:index, :show, :update] do
          member do
            post :cancel
            post :refund
          end
        end

        resources :reviews, only: [:index, :show, :update, :destroy] do
          member do
            post :hide
            post :unhide
            post :flag
            post :unflag
          end
        end

        scope path: "finance", controller: "finance" do
          get "invoices"
          get "payouts"
          get "earnings"
          get "logs"
          post "payouts/:id/trigger", to: "finance#trigger_payout"
          post "refund"
        end

        resources :categories, only: [:index, :create, :update, :destroy]
        resources :plans, only: [:index, :create, :update, :destroy]

        resources :cities, only: [:index, :create, :update, :destroy] do
          collection do
            post "neighborhoods", action: :create_neighborhood
          end
        end

        resources :neighborhoods, only: [:update, :destroy]

        resources :seo_pages, only: [:index, :show, :create, :update, :destroy]

        get "settings", to: "settings#show"
        patch "settings", to: "settings#update"

        resources :staff, only: [:index, :create, :update] do
          collection do
            post :promote
          end
          member do
            post :suspend
          end
        end

        get "reports", to: "reports#index"
        get "reports/export", to: "reports#export"

        resources :claim_requests, only: [:index, :show] do
          member do
            post :approve
            post :reject
          end
        end

        scope path: "support", controller: "support" do
          post "impersonate"
          post "create_booking"
          get "activity_log"
        end
      end

      # ==========================================
      # LEGACY ROUTES (Backward compatibility)
      # ==========================================
      scope path: "auth", controller: "public/auth" do
        get "google", to: "public/auth#google"
        post "register", to: "public/auth#register"
        post "register_provider", to: "public/auth#register_provider"
        post "login", to: "public/auth#login"
        post "refresh", to: "public/auth#refresh"
        delete "logout", to: "public/auth#logout"
        get "me", to: "public/auth#me"
        patch "password", to: "public/auth#password"
        post "forgot_password", to: "public/auth#forgot_password"
        get "validate_reset_token", to: "public/auth#validate_reset_token"
        post "reset_password", to: "public/auth#reset_password"
      end

      resources :businesses, controller: "provider/businesses", as: :legacy_businesses do
        collection do
          get :search
        end
        member do
          get :bookings
          get :stats
          get :staff
          post "staff", action: :invite_staff
          post "staff/:user_id", action: :add_staff
          patch "staff/:user_id", action: :update_staff
          delete "staff/:user_id", action: :remove_staff
          get :availabilities
          post :photos, action: :add_photos
          delete :photos, action: :remove_photo
        end
        resources :services, only: [:index, :create], controller: "provider/services", as: :legacy_services
        resources :reviews, only: [:index], controller: "customer/reviews", as: :legacy_reviews
      end

      resources :services, only: [:show, :update, :destroy], controller: "provider/services",
                           as: :legacy_service_items do
        member do
          get :availability
        end
      end

      resources :bookings, controller: "customer/bookings", as: :legacy_bookings do
        member do
          post :confirm
          post :cancel
          post :complete
        end
      end

      resources :reviews, only: [:show, :create, :update, :destroy], controller: "customer/reviews",
                          as: :legacy_review_items

      post "businesses/:id/track-phone-click", to: "public/businesses#track_phone_click"
      post "businesses/:id/track-profile-view", to: "public/businesses#track_profile_view"
      post "businesses/:id/track-booking-click", to: "public/businesses#track_booking_click"
      post "businesses/:id/track-google-maps-click", to: "public/businesses#track_google_maps_click"
      post "businesses/:id/track-waze-click", to: "public/businesses#track_waze_click"

      scope path: "search_metadata", controller: "public/search_metadata" do
        get "cities"
        get "categories"
        get "categories_hierarchy"
        get "filters"
      end

      scope path: "booking_payments", controller: "customer/booking_payments" do
        post "create_intent", to: "customer/booking_payments#create_intent"
      end

      scope path: "uploads", controller: "provider/uploads" do
        post "image", to: "provider/uploads#image"
        post "cloudinary-sign", to: "provider/uploads#cloudinary_sign"
      end

      # Account
      scope path: "account", controller: "account" do
        get "profile"
        patch "profile", to: "account#update_profile"
        delete "deactivate"
      end

      # Cloudinary
      scope path: "cloudinary", controller: "cloudinary" do
        post "signature"
      end
    end
  end

  # Health checks
  get "up", to: "health#show", as: :rails_health_check
  get "up/ready", to: "health#ready", as: :rails_health_ready
  root to: proc { [200, { "Content-Type" => "text/plain" }, ["OK"]] }

  # ActionCable
  mount ActionCable.server => "/cable"
end
