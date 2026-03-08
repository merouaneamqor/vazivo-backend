# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.2.2"

# Rails framework
gem "rails", "~> 7.1.0"

# Database
gem "pg", "~> 1.5"

# Web server
gem "puma", ">= 5.0"

# JSON
gem "jbuilder"
gem "oj"

# Authentication & Security
gem "devise", "~> 4.9"
gem "jwt", "~> 2.7"
gem "omniauth-google-oauth2", "~> 1.2"
gem "rack-attack", "~> 6.7"
gem "rack-cors", "~> 2.0"

# Authorization
gem "pundit", "~> 2.3"

# Serialization
gem "active_model_serializers", "~> 0.10.0"

# Pagination
gem "pagy", "~> 9.0"

# Soft delete
gem "discard", "~> 1.3"

# Background jobs (connection_pool 3.x uses keyword args for pop; Sidekiq 7.3 calls pop(timeout) positionally)
gem "connection_pool", "~> 2.4"
gem "redis", "~> 5.0"
gem "sidekiq", "~> 7.2"
gem "sidekiq-cron", "~> 1.12"

# File uploads
gem "aws-sdk-s3", "~> 1.141"
gem "carrierwave", "~> 3.0"
gem "cloudinary", "~> 1.28"
gem "image_processing", "~> 1.12"

# Payments
gem "stripe", "~> 10.3"

# HTTP client
gem "httparty", "~> 0.21"

# Email
gem "sendgrid-ruby"

# Geospatial (H3 hexagonal index for location search)
gem "h3", "~> 3.7"

# Translations (column backend for Category name/slug)
gem "mobility", "~> 1.3"

# Error tracking (only activates when SENTRY_DSN is set)
gem "sentry-rails", "~> 5.0"
gem "sentry-ruby", "~> 5.0"
gem "sentry-sidekiq", "~> 5.0"

# Environment variables
gem "dotenv-rails", groups: [:development, :test]

# Performance
gem "bootsnap", require: false

# Real-time
gem "actioncable"

# Timezone data
gem "tzinfo-data", platforms: [:windows, :jruby]

group :development, :test do
  gem "database_cleaner-active_record", "~> 2.1"
  gem "debug", platforms: [:mri, :windows]
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.2"
  gem "rspec-rails", "~> 6.1"
  gem "shoulda-matchers", "~> 5.3"
end

group :development do
  gem "annotate"
  gem "brakeman", require: false
  gem "bullet"
  gem "letter_opener"
  gem "letter_opener_web"
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
end

group :test do
  gem "rspec_junit_formatter", "~> 0.6"
  gem "simplecov", require: false
  gem "timecop", "~> 0.9"
  gem "vcr", "~> 6.2"
  gem "webmock", "~> 3.19"
end
