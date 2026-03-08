# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def welcome_customer(user)
    return if user.blank? || user.email.blank?

    @user = user
    @name = user.name.presence || "there"
    mail(to: user.email, subject: "Welcome to OllaZen")
  end

  def welcome_provider(user, business)
    return if user.blank? || user.email.blank?

    @user = user
    @business = business
    @business_name = business&.name || "your business"
    mail(to: user.email, subject: "Welcome to OllaZen – Your provider account is ready")
  end

  def provider_upgrade_confirmation(user, business)
    return if user.blank? || user.email.blank?

    @user = user
    @business = business
    @business_name = business&.name || "your business"
    mail(to: user.email, subject: "You're now a provider on OllaZen!")
  end
end
