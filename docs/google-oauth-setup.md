# Google OAuth Configuration for Vazivo

## Setup Instructions

### 1. Create OAuth 2.0 Credentials in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project or create a new one
3. Navigate to: **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client ID**
5. Choose **Web application**

### 2. Configure Authorized Redirect URIs

Add these redirect URIs:

**Production:**
```
https://infra.vazivo.com/auth/google_oauth2/callback
```

**Development:**
```
http://localhost:3000/auth/google_oauth2/callback
```

### 3. Set Environment Variables

Add to your environment (Railway, .env, etc.):

```bash
GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your_client_secret
```

### 4. Frontend Configuration

The frontend should redirect to:
```
GET https://infra.vazivo.com/auth/google_oauth2
```

After successful authentication, Google will redirect back to the callback URL, and the backend will:
1. Create/find the user
2. Set authentication cookies
3. Redirect to the frontend with the user session

## Testing

Test the OAuth flow:
1. Click "Sign in with Google" on frontend
2. Should redirect to Google login
3. After approval, redirects back to your app
4. User is logged in

## Current Configuration

- **Scopes**: `userinfo.email`, `userinfo.profile`
- **Prompt**: `select_account` (always shows account picker)
- **Method**: GET requests only (for security)

## Environment Variables Required

```bash
# Backend (.env or Railway)
GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxx

# Frontend (.env.production)
NEXT_PUBLIC_API_URL=https://infra.vazivo.com/api/v1
```
