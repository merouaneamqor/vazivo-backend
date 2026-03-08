# frozen_string_literal: true

require "sidekiq/cron/web"

# Redis URL for Sidekiq. On Railway, the worker often cannot resolve Redis.railway.internal;
# when REDIS_URL is internal, use REDIS_PUBLIC_URL if set (add it on the worker service in Railway).
base_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
redis_url = if base_url.include?("railway.internal") && ENV["REDIS_PUBLIC_URL"].to_s.strip.present?
              ENV["REDIS_PUBLIC_URL"].strip
            else
              ENV["REDIS_PUBLIC_URL"].presence || base_url
            end

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  
  # Load cron jobs
  schedule_file = "config/schedule.yml"
  if File.exist?(schedule_file)
    Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
  end
  
  # Log email delivery errors
  config.error_handlers << proc { |ex, ctx_hash|
    if ctx_hash[:job] && ctx_hash[:job]['class'] == 'ActionMailer::MailDeliveryJob'
      Rails.logger.error("Email delivery failed: #{ex.message}")
      Rails.logger.error("Job context: #{ctx_hash[:job].inspect}")
    end
  }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
