# frozen_string_literal: true

module RequestSpecHelper
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end

  def json_body
    json_response
  end

  def auth_headers(user)
    token = JwtService.encode_access_token(user_id: user.id, role: user.role)
    { "Authorization" => "Bearer #{token}" }
  end

  def sign_in(user)
    @current_user = user
    @auth_headers = auth_headers(user)
  end

  def auth_get(path, params: {}, headers: {})
    get path, params: params, headers: headers.merge(@auth_headers || {})
  end

  def auth_post(path, params: {}, headers: {})
    post path, params: params, headers: headers.merge(@auth_headers || {}), as: :json
  end

  def auth_patch(path, params: {}, headers: {})
    patch path, params: params, headers: headers.merge(@auth_headers || {}), as: :json
  end

  def auth_delete(path, params: {}, headers: {})
    delete path, params: params, headers: headers.merge(@auth_headers || {})
  end
end
