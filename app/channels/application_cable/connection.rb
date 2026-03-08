# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token] || cookies[:access_token]
      return reject_unauthorized_connection unless token

      payload = JwtService.decode_access_token(token)
      User.find(payload[:user_id])
    rescue JwtService::InvalidToken, JwtService::ExpiredToken, ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end
  end
end
