# frozen_string_literal: true

# Load the custom Cloudinary ActiveStorage service
require_relative "../../lib/active_storage/service/cloudinary_service"

# Configure Cloudinary (cloud_name dqssnduni; ENV overrides for other environments)
cloud_name = ENV["CLOUDINARY_CLOUD_NAME"].presence || "dqssnduni"
api_key = ENV.fetch("CLOUDINARY_API_KEY", nil)
api_secret = ENV.fetch("CLOUDINARY_API_SECRET", nil)

if cloud_name && api_key.present? && api_secret.present?
  Cloudinary.config do |config|
    config.cloud_name = cloud_name
    config.api_key = api_key
    config.api_secret = api_secret
    config.secure = true
  end
end
