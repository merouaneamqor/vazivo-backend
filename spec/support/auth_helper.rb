# frozen_string_literal: true

module AuthHelper
  def generate_token(user)
    JwtService.encode_access_token(user_id: user.id, role: user.role)
  end

  def generate_expired_token(user)
    payload = { user_id: user.id, role: user.role, exp: 1.hour.ago.to_i }
    JWT.encode(payload, JwtService.access_secret, "HS256")
  end

  def auth_headers_for(user)
    token = generate_token(user)
    { "Authorization" => "Bearer #{token}" }
  end
end
