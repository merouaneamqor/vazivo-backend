# frozen_string_literal: true

# Google OAuth: set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in env.
# In Google Cloud Console: APIs & Services → Credentials → OAuth 2.0 Client ID (Web application).
# Authorized redirect URI: https://your-backend.com/auth/google_oauth2/callback
#
# Insert after Session so OmniAuth can store OAuth state in the session. Session is at the start (application.rb).
Rails.application.config.middleware.insert_after(
  ActionDispatch::Session::CookieStore,
  OmniAuth::Builder
) do
  provider :google_oauth2,
           ENV.fetch("GOOGLE_CLIENT_ID", nil),
           ENV.fetch("GOOGLE_CLIENT_SECRET", nil),
           scope: "userinfo.email,userinfo.profile",
           prompt: "select_account"
end

OmniAuth.config.allowed_request_methods = [:get]
