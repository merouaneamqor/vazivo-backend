# frozen_string_literal: true

# Rack::Attack configuration for rate limiting

module Rack
  class Attack
    ### Configure cache ###
    # Use Rails cache (which can be configured to use Redis)
    Rack::Attack.cache.store = Rails.cache

    ### Safelist: never throttle health checks (Railway / load balancers) ###
    safelist("allow-health") { |req| ["/up", "/up/ready", "/"].include?(req.path) }

    ### Throttle Spammy Clients ###
    # Throttle all requests by IP (60rpm)
    throttle("req/ip", limit: ENV.fetch("RATE_LIMIT_REQUESTS_PER_MINUTE", 60).to_i, period: 1.minute) do |req|
      req.ip unless req.path.start_with?("/assets") || req.path == "/up" || req.path == "/up/ready" || req.path == "/"
    end

    ### Throttle Login Attempts ###
    # Throttle POST requests to /api/v1/auth/login by IP address
    throttle("logins/ip", limit: ENV.fetch("THROTTLE_LOGIN_LIMIT", 5).to_i,
                          period: ENV.fetch("THROTTLE_LOGIN_PERIOD", 20).to_i.seconds) do |req|
      req.ip if req.path == "/api/v1/auth/login" && req.post?
    end

    # Throttle POST requests to /api/v1/auth/login by email
    throttle("logins/email", limit: ENV.fetch("THROTTLE_LOGIN_LIMIT", 5).to_i,
                             period: ENV.fetch("THROTTLE_LOGIN_PERIOD", 20).to_i.seconds) do |req|
      if req.path == "/api/v1/auth/login" && req.post?
        # Normalize email and use as discriminator
        req.params.dig("user", "email")&.downcase&.gsub(/\s+/, "")
      end
    end

    ### Throttle Password Reset ###
    throttle("password_reset/ip", limit: 5, period: 1.hour) do |req|
      req.ip if req.path == "/api/v1/auth/forgot_password" && req.post?
    end

    ### Throttle Registrations ###
    throttle("registrations/ip", limit: 10, period: 1.hour) do |req|
      req.ip if req.path == "/api/v1/auth/register" && req.post?
    end

    ### Throttle API Heavy Endpoints ###
    throttle("search/ip", limit: 30, period: 1.minute) do |req|
      req.ip if req.path.include?("/search") && req.get?
    end

    ### Custom Response ###
    self.throttled_responder = ->(request) do
      match_data = request.env["rack.attack.match_data"]
      now = Time.current

      headers = {
        "Content-Type" => "application/json",
        "Retry-After" => (match_data[:period] - (now.to_i % match_data[:period])).to_s,
        "X-RateLimit-Limit" => match_data[:limit].to_s,
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset" => (now + (match_data[:period] - (now.to_i % match_data[:period]))).to_i.to_s,
      }

      [429, headers, [{ error: "Rate limit exceeded. Please retry later." }.to_json]]
    end

    ### Logging ###
    ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
      Rails.logger.warn "[Rack::Attack] Throttled #{payload[:request].ip} for #{payload[:match_type]}"
    end
  end
end
