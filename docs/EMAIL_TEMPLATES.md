# Email Templates

Sample transactional email templates for SendGrid compliance.

## Booking Confirmation Email

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Booking Confirmation</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  
  <!-- Header -->
  <div style="text-align: center; padding: 20px 0; border-bottom: 2px solid #8b5cf6;">
    <h1 style="color: #8b5cf6; margin: 0;">OllaZen</h1>
    <p style="color: #666; margin: 5px 0;">Your Beauty & Wellness Platform</p>
  </div>

  <!-- Main Content -->
  <div style="padding: 30px 0;">
    <h2 style="color: #0a0a0a;">Booking Confirmed! ✓</h2>
    
    <p>Hi {{customer_name}},</p>
    
    <p>Your booking has been confirmed. Here are the details:</p>
    
    <!-- Booking Details -->
    <div style="background: #f9fafb; border-left: 4px solid #8b5cf6; padding: 20px; margin: 20px 0;">
      <p style="margin: 5px 0;"><strong>Service:</strong> {{service_name}}</p>
      <p style="margin: 5px 0;"><strong>Provider:</strong> {{business_name}}</p>
      <p style="margin: 5px 0;"><strong>Date:</strong> {{booking_date}}</p>
      <p style="margin: 5px 0;"><strong>Time:</strong> {{booking_time}}</p>
      <p style="margin: 5px 0;"><strong>Duration:</strong> {{duration}} minutes</p>
      <p style="margin: 5px 0;"><strong>Price:</strong> ${{price}}</p>
      <p style="margin: 5px 0;"><strong>Booking ID:</strong> {{booking_id}}</p>
    </div>

    <!-- Location -->
    <div style="margin: 20px 0;">
      <h3 style="color: #0a0a0a;">Location</h3>
      <p>{{business_address}}</p>
    </div>

    <!-- CTA Button -->
    <div style="text-align: center; margin: 30px 0;">
      <a href="{{booking_url}}" style="background: #8b5cf6; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block;">View Booking Details</a>
    </div>

    <p>Need to make changes? You can manage your booking from your dashboard.</p>
  </div>

  <!-- Footer -->
  <div style="border-top: 1px solid #e5e7eb; padding-top: 20px; margin-top: 30px; font-size: 12px; color: #666;">
    <p style="margin: 10px 0;">
      <strong>OllaZen</strong><br>
      [Your Business Address]<br>
      [City, State ZIP]<br>
      [Country]
    </p>
    
    <p style="margin: 10px 0;">
      <a href="{{app_url}}/privacy" style="color: #8b5cf6; text-decoration: none;">Privacy Policy</a> | 
      <a href="{{app_url}}/terms" style="color: #8b5cf6; text-decoration: none;">Terms of Service</a> | 
      <a href="{{app_url}}/contact" style="color: #8b5cf6; text-decoration: none;">Contact Us</a>
    </p>
    
    <p style="margin: 10px 0;">
      <a href="{{app_url}}/unsubscribe?email={{customer_email}}&token={{unsubscribe_token}}" style="color: #666; text-decoration: underline;">Manage Email Preferences</a>
    </p>
    
    <p style="margin: 10px 0; color: #999;">
      This is a transactional email related to your booking. You received this because you made a booking on OllaZen.
    </p>
  </div>

</body>
</html>
```

## Booking Reminder Email

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Booking Reminder</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  
  <div style="text-align: center; padding: 20px 0; border-bottom: 2px solid #8b5cf6;">
    <h1 style="color: #8b5cf6; margin: 0;">OllaZen</h1>
  </div>

  <div style="padding: 30px 0;">
    <h2 style="color: #0a0a0a;">Reminder: Upcoming Appointment</h2>
    
    <p>Hi {{customer_name}},</p>
    
    <p>This is a friendly reminder about your upcoming appointment:</p>
    
    <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 20px; margin: 20px 0;">
      <p style="margin: 5px 0;"><strong>Service:</strong> {{service_name}}</p>
      <p style="margin: 5px 0;"><strong>Date:</strong> {{booking_date}}</p>
      <p style="margin: 5px 0;"><strong>Time:</strong> {{booking_time}}</p>
      <p style="margin: 5px 0;"><strong>Location:</strong> {{business_name}}</p>
    </div>

    <div style="text-align: center; margin: 30px 0;">
      <a href="{{booking_url}}" style="background: #8b5cf6; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; display: inline-block;">View Details</a>
    </div>

    <p>See you soon!</p>
  </div>

  <div style="border-top: 1px solid #e5e7eb; padding-top: 20px; margin-top: 30px; font-size: 12px; color: #666;">
    <p style="margin: 10px 0;">
      <strong>OllaZen</strong><br>
      [Your Business Address]<br>
      [City, State ZIP]<br>
      [Country]
    </p>
    
    <p style="margin: 10px 0;">
      <a href="{{app_url}}/privacy" style="color: #8b5cf6;">Privacy Policy</a> | 
      <a href="{{app_url}}/terms" style="color: #8b5cf6;">Terms</a> | 
      <a href="{{app_url}}/unsubscribe?email={{customer_email}}&token={{unsubscribe_token}}" style="color: #666;">Unsubscribe</a>
    </p>
  </div>

</body>
</html>
```

## Variables to Replace

When sending emails, replace these placeholders:
- `{{customer_name}}` - Customer's name
- `{{customer_email}}` - Customer's email
- `{{unsubscribe_token}}` - Secure token for unsubscribe (generate unique per user)
- `{{service_name}}` - Name of the booked service
- `{{business_name}}` - Provider business name
- `{{business_address}}` - Full business address
- `{{booking_date}}` - Formatted date (e.g., "Monday, March 15, 2026")
- `{{booking_time}}` - Time (e.g., "2:00 PM")
- `{{duration}}` - Service duration in minutes
- `{{price}}` - Service price
- `{{booking_id}}` - Unique booking identifier
- `{{booking_url}}` - Link to booking details page
- `{{app_url}}` - Your application base URL

## Unsubscribe Token Generation

Generate a secure unsubscribe token for each user:

```ruby
# Example in Ruby/Rails
def generate_unsubscribe_token(user)
  payload = {
    user_id: user.id,
    email: user.email,
    exp: 90.days.from_now.to_i
  }
  JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
end

# Verify token on unsubscribe
def verify_unsubscribe_token(token, email)
  decoded = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
  payload = decoded.first
  payload['email'] == email
rescue JWT::DecodeError, JWT::ExpiredSignature
  false
end
```

The unsubscribe URL format: `{{app_url}}/unsubscribe?email={{customer_email}}&token={{unsubscribe_token}}`

## Required Elements (SendGrid Compliance)

All transactional emails must include:
1. ✓ Physical mailing address (in footer)
2. ✓ Privacy Policy link
3. ✓ Unsubscribe/Email preferences link
4. ✓ Clear sender identification
5. ✓ Reason for receiving the email
