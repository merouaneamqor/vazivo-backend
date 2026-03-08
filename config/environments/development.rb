# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true

  # Allow requests from frontend container via Docker networking
  config.hosts << "host.docker.internal"

  # Use polling file watcher in Docker so code changes on bind mount are detected without rebuild
  config.file_watcher = ActiveSupport::FileUpdateChecker if ENV["RAILS_USE_POLLING"] == "true"

  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  # Use Cloudinary for file storage in development
  config.active_storage.service = :cloudinary if defined?(ActiveStorage)

  # Email delivery in development
  if ENV["USE_LETTER_OPENER"] == "true"
    config.action_mailer.delivery_method = :letter_opener
  else
    config.action_mailer.delivery_method = :sendgrid_api
  end

  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = { host: ENV.fetch("FRONTEND_URL", "http://localhost:3001") }

  config.active_support.deprecation = :log
  config.active_support.disallowed_deprecation = :raise
  config.active_support.disallowed_deprecation_warnings = []
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
end
