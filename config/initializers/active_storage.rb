# frozen_string_literal: true

Rails.application.config.after_initialize do
  # Configure ActiveStorage URL options
  if Rails.env.development?
    # Use MinIO public endpoint for development
    Rails.application.routes.default_url_options[:host] = ENV.fetch("FRONTEND_URL", "http://localhost:3001")
  elsif Rails.env.production?
    # Use the configured domain in production
    Rails.application.routes.default_url_options[:host] = ENV["DOMAIN"] || "localhost"
    Rails.application.routes.default_url_options[:protocol] = "https"
  end
end

# Configure variant processor
Rails.application.config.active_storage.variant_processor = :mini_magick

# Configure direct uploads
Rails.application.config.active_storage.service_urls_expire_in = 1.hour

# Track variants in database for better performance
Rails.application.config.active_storage.track_variants = true
