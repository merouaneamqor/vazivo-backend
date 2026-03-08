# frozen_string_literal: true

class JwtService
  class << self
    def access_secret
      ENV.fetch("JWT_SECRET") { Rails.application.secret_key_base }
    end

    def refresh_secret
      ENV.fetch("JWT_REFRESH_SECRET") { "#{access_secret}_refresh" }
    end

    def access_expiration
      ENV.fetch("JWT_EXPIRATION_HOURS", 1).to_i.hours
    end

    def refresh_expiration
      ENV.fetch("JWT_REFRESH_EXPIRATION_HOURS", 168).to_i.hours
    end

    # Generate access token
    def encode_access_token(payload)
      encode(payload, access_secret, access_expiration)
    end

    # Generate refresh token
    def encode_refresh_token(payload)
      encode(payload, refresh_secret, refresh_expiration)
    end

    # Decode access token
    def decode_access_token(token)
      decode(token, access_secret)
    end

    # Decode refresh token
    def decode_refresh_token(token)
      decode(token, refresh_secret)
    end

    # Generate token pair
    def generate_tokens(user, impersonator: nil)
      payload = { user_id: user.id, role: user.role }
      payload[:impersonator_id] = impersonator.id if impersonator
      payload[:impersonator_role] = impersonator.role if impersonator

      {
        access_token: encode_access_token(payload),
        refresh_token: encode_refresh_token(payload.merge(token_type: "refresh")),
        expires_in: access_expiration.to_i,
      }
    end

    # Refresh tokens using refresh token
    def refresh_tokens(refresh_token)
      payload = decode_refresh_token(refresh_token)
      raise InvalidToken, "Invalid token type" unless payload[:token_type] == "refresh"

      user = User.find(payload[:user_id])
      generate_tokens(user)
    rescue ActiveRecord::RecordNotFound
      raise InvalidToken, "User not found"
    end

    private

    def encode(payload, secret, expiration)
      payload = payload.dup
      payload[:exp] = expiration.from_now.to_i
      payload[:iat] = Time.current.to_i
      payload[:jti] = SecureRandom.uuid

      JWT.encode(payload, secret, "HS256")
    end

    def decode(token, secret)
      decoded = JWT.decode(token, secret, true, { algorithm: "HS256" })
      ActiveSupport::HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature
      raise ExpiredToken, "Token has expired"
    rescue JWT::DecodeError => e
      raise InvalidToken, "Invalid token: #{e.message}"
    end
  end

  class ExpiredToken < StandardError; end
  class InvalidToken < StandardError; end
end
