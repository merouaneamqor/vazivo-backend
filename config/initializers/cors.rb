# frozen_string_literal: true

# CORS: staging or CORS_ALLOW_ALL=1 = allow any origin (block reflects request origin); else use FRONTEND_URL / CORS_ORIGINS.
cors_allow_all = Rails.env.staging? || ENV["CORS_ALLOW_ALL"] == "1"
cors_origins_list = [
  ENV.fetch("FRONTEND_URL", nil),
  ENV["CORS_ORIGINS"]&.split(",")&.map(&:strip),
].flatten.compact.uniq
cors_origins_list << "http://localhost:3001" if cors_origins_list.empty?

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Block form: return truthy to allow; with credentials we must reflect origin (no '*').
    origins do |source, _env|
      if cors_allow_all
        source
      elsif source && cors_origins_list.any? { |o| o.is_a?(Regexp) ? source.match?(o) : o == source }
        source
      end
    end

    resource "*",
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             credentials: true,
             expose: ["Authorization", "X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset"],
             max_age: 86_400
  end
end
