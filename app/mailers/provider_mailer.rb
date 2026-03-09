# frozen_string_literal: true

class ProviderMailer < ApplicationMailer
  def provider_approved(user, business)
    return if user.blank? || !user.email?

    @user = user
    @business = business
    @business_name = business&.name || "your business"
    mail(to: user.email, subject: "Your Vazivo provider account is approved")
  end

  def premium_confirmation(user, business: nil, expires_at: nil)
    return if user.blank? || !user.email?

    @user = user
    @business = business
    @business_name = business&.name || "your business"
    @expires_at = expires_at
    mail(to: user.email, subject: "Premium subscription confirmed – Vazivo")
  end
end
