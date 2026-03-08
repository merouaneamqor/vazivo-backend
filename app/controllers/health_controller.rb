# frozen_string_literal: true

class HealthController < ActionController::API
  before_action :set_cors_headers

  def index
    render json: {
      status: 'ok',
      timestamp: Time.current
    }
  end

  private

  def set_cors_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Content-Type'
  end
end
