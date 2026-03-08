# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.active_support.deprecation = :notify
  config.active_support.disallowed_deprecation = :log
  config.active_support.disallowed_deprecation_warnings = []
  config.log_tags = [:request_id]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use Cloudinary for file storage in production
  config.active_storage.service = :cloudinary if defined?(ActiveStorage)

  # Email delivery via SendGrid API (SMTP port 587 is blocked on Railway)
  config.action_mailer.delivery_method = :sendgrid_api

  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: ENV["FRONTEND_URL"] || ENV.fetch("DOMAIN", nil) }

  # Force SSL in production
  config.force_ssl = ENV["FORCE_SSL"] != "false"

  # Configure hosts
  config.hosts << ENV["DOMAIN"] if ENV["DOMAIN"].present?
  config.hosts << /.*\.#{ENV["DOMAIN"]}/ if ENV["DOMAIN"].present?

  config.active_record.dump_schema_after_migration = false
end
