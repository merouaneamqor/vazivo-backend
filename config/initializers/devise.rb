# frozen_string_literal: true

# Devise configuration for API-only app. JWT handled separately; Devise used for
# User model (database_authenticatable, validatable, recoverable).
Devise.setup do |config|
  config.secret_key = ENV.fetch("SECRET_KEY_BASE") { Rails.application.credentials.secret_key_base }

  config.mailer_sender = ENV.fetch("MAILER_SENDER", "Vazivo <contact@vazivo.com>")
  config.mailer = "CustomDeviseMailer"

  require "devise/orm/active_record"

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  config.skip_session_storage = [:http_auth]

  config.stretches = Rails.env.test? ? 1 : 12

  config.reset_password_within = 6.hours

  config.expire_all_remember_me_on_sign_out = true

  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  config.navigational_formats = []

  config.sign_out_via = :delete

  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other
end
