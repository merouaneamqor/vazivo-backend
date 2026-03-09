# frozen_string_literal: true

# Sentry: error tracking and performance.
# Backend will NOT report to Sentry unless SENTRY_DSN is set in the environment
# (e.g. in production/staging). Get your DSN at https://sentry.io → Project → Client Keys (DSN).
if ENV["SENTRY_DSN"].to_s.strip.present?
  Sentry.init do |config|
    config.dsn = ENV.fetch("SENTRY_DSN", nil)
    config.environment = ENV.fetch("RAILS_ENV", Rails.env)
    config.release = ENV["SENTRY_RELEASE"].presence
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.send_default_pii = false
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
    config.debug = ENV["SENTRY_DEBUG"] == "true"
  end

  # Report Sidekiq job errors to Sentry
  require "sentry-sidekiq" if defined?(Sidekiq)

  Rails.logger.info "[Sentry] Initialized for env=#{Sentry.configuration.environment}"
else
  Rails.logger.warn "[Sentry] SENTRY_DSN is not set — errors will not be reported to Sentry. Set SENTRY_DSN in production/staging."
end
