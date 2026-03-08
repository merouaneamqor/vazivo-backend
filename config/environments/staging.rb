# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # Staging: use SECRET_KEY_BASE from environment (e.g. Railway variables)
  config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") do
    raise ArgumentError, "Missing SECRET_KEY_BASE for staging. Set it in your environment (e.g. Railway Variables)."
  end

  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
  config.active_support.deprecation = :notify
  config.active_support.disallowed_deprecation = :log
  config.active_support.disallowed_deprecation_warnings = []
  config.log_tags = [:request_id]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use same storage as production or local (set ACTIVE_STORAGE_SERVICE=local for staging)
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "local").to_sym if defined?(ActiveStorage)

  # SMTP for email delivery (SendGrid)
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp.sendgrid.net",
    port: 587,
    user_name: "apikey",
    password: ENV.fetch("SENDGRID_API_KEY", nil),
    authentication: :plain,
    enable_starttls_auto: true
  }

  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: ENV["FRONTEND_URL"] || ENV.fetch("DOMAIN", "localhost:3001") }

  config.force_ssl = ENV["FORCE_SSL"] != "false"

  # TEMPORARY: allow all hosts for testing (revert before production)
  config.hosts.clear
  config.hosts << proc { true }

  config.active_record.dump_schema_after_migration = false
end
