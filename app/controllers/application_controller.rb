# frozen_string_literal: true

# Load Pagy before include (avoids NameError when controllers load before initializers)
require "pagy"
require "pagy/backend"

class ApplicationController < ActionController::API
  include ActionController::Cookies
  include Pundit::Authorization
  include Pagy::Backend

  before_action :set_default_format
  before_action :set_locale
  before_action :verify_db_connection

  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from Pundit::NotAuthorizedError, with: :forbidden
  rescue_from JwtService::ExpiredToken, with: :unauthorized
  rescue_from JwtService::InvalidToken, with: :unauthorized
  rescue_from ActionController::ParameterMissing, with: :bad_request

  # Override Pundit's authorization context to include impersonator and optional dynamic context
  def pundit_user
    {
      user: current_user,
      impersonator: @impersonator,
      **policy_context,
    }.compact
  end

  # Override in controllers to pass request/params/time/feature_flags for dynamic policies
  def policy_context
    {
      request: request,
      params: params.to_unsafe_h.with_indifferent_access,
      time: Time.current,
    }
  end

  private

  # Ensure DB connection is alive (reconnect if dropped, e.g. after idle timeout on Railway).
  def verify_db_connection
    ActiveRecord::Base.connection.verify!
  end

  def set_default_format
    request.format = :json
  end

  def set_locale
    raw = request.headers["X-Locale"].presence || request.env["HTTP_X_LOCALE"].presence
    locale = raw ||
             params[:locale].presence ||
             extract_locale_from_header ||
             I18n.default_locale.to_s
    locale = locale.to_s.downcase.split(/-|_/).first
    locale = I18n.default_locale.to_s unless I18n.available_locales.map(&:to_s).include?(locale)
    I18n.locale = locale.to_sym
    Mobility.locale = I18n.locale if defined?(Mobility)
  end

  def extract_locale_from_header
    accept_language = request.headers["Accept-Language"]
    return nil unless accept_language

    locale = accept_language.scan(/^[a-z]{2}/).first
    I18n.available_locales.map(&:to_s).include?(locale) ? locale : nil
  end

  def authenticate_user!
    token = extract_token
    return unauthorized("Missing authentication token") unless token

    payload = JwtService.decode_access_token(token)
    @current_user = User.kept.find(payload[:user_id])
    @impersonator = User.kept.find(payload[:impersonator_id]) if payload[:impersonator_id]
  rescue ActiveRecord::RecordNotFound
    unauthorized("User not found")
  end

  attr_reader :current_user, :impersonator

  def extract_token
    # Try Authorization header first
    auth_header = request.headers["Authorization"]
    return auth_header.split.last if auth_header.present? && auth_header.start_with?("Bearer ")

    # Fall back to cookie (plain cookie so frontend middleware can read JWT)
    cookies[:access_token]
  end

  # Pagination meta for JSON (expects @pagy to be set by pagy(...))
  # Pagy 9 uses .limit for per-page count (not .items)
  def pagination_meta(_collection = nil)
    {
      current_page: @pagy.page,
      total_pages: @pagy.pages,
      total_count: @pagy.count,
      per_page: @pagy.limit,
    }
  end

  # Response helpers
  def render_success(data, status: :ok, meta: nil)
    response = data
    response[:meta] = meta if meta
    render json: response, status: status
  end

  def render_error(message, status: :unprocessable_content)
    render json: { error: message }, status: status
  end

  def render_errors(errors, status: :unprocessable_content)
    render json: { errors: Array(errors) }, status: status
  end

  # Error handlers (report to Sentry when configured so rescued errors are visible)
  def not_found(exception_or_message = nil)
    capture_sentry(exception_or_message) if exception_or_message.is_a?(Exception)
    message = exception_or_message.is_a?(Exception) ? "Resource not found" : (exception_or_message || "Resource not found")
    render json: { error: message }, status: :not_found
  end

  def unauthorized(message = "Unauthorized")
    render json: { error: message }, status: :unauthorized
  end

  def forbidden(exception = nil)
    capture_sentry(exception)
    render json: { error: "You are not authorized to perform this action" }, status: :forbidden
  end

  def bad_request(exception)
    capture_sentry(exception)
    render json: { error: exception.message }, status: :bad_request
  end

  def unprocessable_entity(exception)
    capture_sentry(exception)
    render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_content
  end

  def capture_sentry(exception)
    return unless exception.is_a?(Exception)
    return unless defined?(Sentry)

    dsn = begin
      Sentry.configuration&.dsn
    rescue StandardError
      nil
    end
    return if dsn.blank?

    Sentry.capture_exception(exception)
  rescue StandardError
    # Never let Sentry reporting break the response
    nil
  end
end
