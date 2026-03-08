# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_cable/engine"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

# Ensure Pagy is loaded before ApplicationController (include Pagy::Backend)
require "pagy"
require "pagy/backend"

module Backend
  class Application < Rails::Application
    config.load_defaults 7.1
    config.autoload_lib(ignore: ["assets", "tasks"])

    # API-only mode
    config.api_only = true

    # Time zone
    config.time_zone = "UTC"

    # Active Record
    config.active_record.default_timezone = :utc

    # Active Job: use Sidekiq when Redis is configured (REDIS_URL or REDIS_PUBLIC_URL);
    # otherwise :inline so jobs run in-process and no Redis is required.
    redis_configured = ENV["REDIS_URL"].to_s.strip.present? || ENV["REDIS_PUBLIC_URL"].to_s.strip.present?
    config.active_job.queue_adapter = redis_configured ? :sidekiq : :inline

    # Internationalization
    config.i18n.default_locale = ENV.fetch("DEFAULT_LOCALE", "fr").to_sym
    config.i18n.available_locales = [:en, :fr, :ar]
    config.i18n.fallbacks = true

    # Generators
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end

    # Middleware
    config.middleware.use Rack::Attack

    # Session (for cookies and for OmniAuth Google OAuth state). Insert at start so they run before OmniAuth.
    config.middleware.insert 0, ActionDispatch::Session::CookieStore, key: "_glow_session"
    config.middleware.insert 0, ActionDispatch::Cookies

    # Active Storage variants
    config.active_storage.variant_processor = :mini_magick
  end
end
