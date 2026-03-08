# frozen_string_literal: true

class SmsService
  def self.send_booking_confirmation(booking)
    phone = booking.user_id.present? ? booking.user&.phone : booking.customer_phone
    return if phone.blank?

    business_name = booking.business&.name || "Us"
    date_str = booking.date&.strftime("%B %d, %Y")
    time_str = booking.start_time&.strftime("%l:%M %p")&.strip
    ref = booking.short_booking_id

    body = "Your booking at #{business_name} on #{date_str} at #{time_str} is confirmed. Reply STOP to unsubscribe. Ref: ##{ref}"

    send_sms(to: normalize_phone(phone), body: body)
  end

  def self.send_new_booking_notification_to_provider(booking)
    phone = booking.business&.user&.phone
    return if phone.blank?

    business_name = booking.business&.name || "Your business"
    date_str = booking.date&.strftime("%B %d, %Y")
    time_str = booking.start_time&.strftime("%l:%M %p")&.strip
    ref = booking.short_booking_id
    customer = booking.user_id.present? ? booking.user&.name : booking.customer_name
    customer = customer.presence || "A customer"

    body = "New booking at #{business_name}: #{customer} on #{date_str} at #{time_str}. Ref: ##{ref}"

    send_sms(to: normalize_phone(phone), body: body)
  end

  def self.send_sms(to:, body:)
    sid = ENV["TWILIO_ACCOUNT_SID"]
    token = ENV["TWILIO_AUTH_TOKEN"]
    from = ENV["TWILIO_FROM_NUMBER"]

    if sid.blank? || token.blank? || from.blank?
      Rails.logger.warn "[SmsService] Twilio credentials not configured"
      return false
    end

    url = "https://api.twilio.com/2010-04-01/Accounts/#{sid}/Messages.json"

    begin
      response = HTTParty.post(
        url,
        basic_auth: { username: sid, password: token },
        body: { To: to, From: from, Body: body },
        format: :json
      )

      if response&.success?
        true
      else
        Rails.logger.warn "[SmsService] Twilio error: #{response&.code} #{response&.body}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "[SmsService] #{e.class}: #{e.message}"
      false
    end
  end

  def self.normalize_phone(phone)
    return nil if phone.blank?

    # Strip spaces and dashes; ensure E.164 if needed (caller can pass +1...)
    phone.to_s.gsub(/\s|-/, "")
  end
end
