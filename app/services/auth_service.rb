# frozen_string_literal: true

class AuthService
  attr_reader :errors

  def initialize
    @errors = []
  end

  # Register a new user
  def register(params)
    user = User.new(params)

    if user.save
      link_guest_bookings_to_user(user)
      tokens = JwtService.generate_tokens(user)
      { success: true, user: user, tokens: tokens }
    else
      @errors = user.errors.full_messages
      { success: false, errors: @errors }
    end
  end

  # Authenticate user with email and password (Devise find_for_database_authentication + valid_password?)
  def login(email, password)
    user = User.find_for_database_authentication(email: email&.downcase)

    if user&.valid_password?(password)
      if user.discarded?
        @errors = ["Account has been deactivated"]
        return { success: false, errors: @errors }
      end

      user.update(last_login_at: Time.current)
      tokens = JwtService.generate_tokens(user)
      { success: true, user: user, tokens: tokens }
    else
      @errors = ["Invalid email or password"]
      { success: false, errors: @errors }
    end
  end

  # Refresh access token
  def refresh(refresh_token)
    tokens = JwtService.refresh_tokens(refresh_token)
    { success: true, tokens: tokens }
  rescue JwtService::ExpiredToken
    @errors = ["Refresh token has expired"]
    { success: false, errors: @errors }
  rescue JwtService::InvalidToken => e
    @errors = [e.message]
    { success: false, errors: @errors }
  end

  # Update user password (Devise update_with_password)
  def update_password(user, current_password, new_password, new_password_confirmation)
    unless user.valid_password?(current_password)
      @errors = ["Current password is incorrect"]
      return { success: false, errors: @errors }
    end

    if user.update_with_password(
      current_password: current_password,
      password: new_password,
      password_confirmation: new_password_confirmation
    )
      { success: true }
    else
      @errors = user.errors.full_messages
      { success: false, errors: @errors }
    end
  end

  # Request password reset (Devise send_reset_password_instructions)
  def request_password_reset(email)
    user = User.find_for_database_authentication(email: email&.downcase)

    user&.send_reset_password_instructions
    # Always return success to prevent email enumeration
    { success: true, message: "Password reset instructions sent" }
  end

  # Validate reset token
  def validate_reset_token(token, email)
    return { valid: false, error: "Token and email are required" } if token.blank? || email.blank?

    user = User.find_for_database_authentication(email: email&.downcase)
    return { valid: false, error: "Invalid token" } unless user

    # Check if token matches (Devise stores hashed token)
    token_valid = Devise.token_generator.digest(User, :reset_password_token, token) == user.reset_password_token
    return { valid: false, error: "Invalid token" } unless token_valid

    # Check if token expired (default 6 hours in Devise)
    token_expired = user.reset_password_sent_at && user.reset_password_sent_at < User.reset_password_within.ago
    return { valid: false, error: "Token expired" } if token_expired

    { valid: true }
  end

  # Reset password with token
  def reset_password(token, email, new_password)
    if token.blank? || email.blank? || new_password.blank?
      return { success: false,
               errors: ["Token, email and password are required"] }
    end

    user = User.find_for_database_authentication(email: email&.downcase)
    return { success: false, errors: ["Invalid token"] } unless user

    # Validate token
    validation = validate_reset_token(token, email)
    return { success: false, errors: [validation[:error]] } unless validation[:valid]

    # Reset password
    user.password = new_password
    user.reset_password_token = nil
    user.reset_password_sent_at = nil

    if user.save
      { success: true, message: "Password has been reset" }
    else
      { success: false, errors: user.errors.full_messages }
    end
  end

  # Find or create user from Google OAuth (OmniAuth auth hash).
  # Links existing account by email if present; otherwise creates customer with random password.
  def find_or_create_from_google(auth)
    uid = auth["uid"]
    email = auth.dig("info", "email")&.downcase&.strip
    name = auth.dig("info", "name")&.strip.presence || email&.split("@")&.first || "User"
    auth.dig("info", "image")

    return { success: false, errors: ["Google account has no email"] } if email.blank?

    user = User.kept.find_by(oauth_provider: "google_oauth2", oauth_uid: uid)
    user ||= User.kept.find_for_database_authentication(email: email)

    if user
      user.update!(oauth_provider: "google_oauth2", oauth_uid: uid) unless user.oauth_provider?
      user.update!(last_login_at: Time.current)
      tokens = JwtService.generate_tokens(user)
      return { success: true, user: user, tokens: tokens }
    end

    user = User.new(
      email: email,
      name: name,
      role: "customer",
      oauth_provider: "google_oauth2",
      oauth_uid: uid,
      password: SecureRandom.hex(32)
    )
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
    if user.save
      link_guest_bookings_to_user(user)
      UserMailer.welcome_customer(user).deliver_later
      DiscordNotifier.notify_embed(
        title: "New signup (Google)",
        description: "A new customer signed up with Google.",
        fields: [
          { name: "Email", value: user.email, inline: true },
          { name: "Name", value: user.name, inline: true },
        ],
        color: 0x5865f2
      )
      tokens = JwtService.generate_tokens(user)
      { success: true, user: user, tokens: tokens }
    else
      @errors = user.errors.full_messages
      { success: false, errors: @errors }
    end
  end

  private

  def link_guest_bookings_to_user(user)
    Booking.for_guest_lookup(email: user.email, phone: user.phone).update_all(user_id: user.id)
  end
end
