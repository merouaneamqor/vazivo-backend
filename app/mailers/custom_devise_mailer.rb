# frozen_string_literal: true

class CustomDeviseMailer < Devise::Mailer
  # Override so the reset email uses a frontend URL (no edit_password_url route in API-only app).
  def reset_password_instructions(record, token, opts = {})
    frontend_base = ENV["FRONTEND_URL"].presence || "http://localhost:3001"
    @reset_url = "#{frontend_base.chomp('/')}/reset-password?token=#{token}&email=#{ERB::Util.url_encode(record.email)}"
    super
  end

  def confirmation_instructions(record, token, opts = {})
    frontend_base = ENV["FRONTEND_URL"].presence || "http://localhost:3001"
    @confirmation_url = "#{frontend_base.chomp('/')}/confirm-email?token=#{token}"
    super
  end
end
