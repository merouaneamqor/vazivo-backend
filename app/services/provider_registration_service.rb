# frozen_string_literal: true

class ProviderRegistrationService
  attr_reader :errors

  def initialize
    @errors = []
  end

  def call(user_params:, business_params:)
    user = nil
    business = nil

    ActiveRecord::Base.transaction do
      name = if user_params[:first_name].present?
               [user_params[:first_name], user_params[:last_name]].compact.join(" ")
             else
               user_params[:name]
             end
      user = User.new(
        name: name,
        email: user_params[:email]&.downcase,
        phone: user_params[:phone].presence,
        password: user_params[:password],
        password_confirmation: user_params[:password_confirmation],
        role: "provider",
        provider_status: "not_confirmed"
      )

      unless user.save
        @errors = user.errors.full_messages
        raise ActiveRecord::Rollback
      end

      categories_array = Array(business_params[:categories]).compact_blank
      primary_category = categories_array.first.presence || business_params[:category].presence

      business = user.businesses.build(
        name: business_params[:name],
        description: business_params[:description].presence,
        category: primary_category,
        categories: categories_array.presence || (primary_category ? [primary_category] : []),
        address: business_params[:address],
        city: business_params[:city],
        country: business_params[:country].presence,
        neighborhood: business_params[:neighborhood].presence,
        phone: business_params[:phone].presence,
        email: business_params[:email].presence,
        website: business_params[:website].presence,
        opening_hours: normalize_opening_hours(business_params[:opening_hours] || {}),
        verification_status: "pending"
      )

      unless business.save
        @errors = business.errors.full_messages
        raise ActiveRecord::Rollback
      end
    end

    if user&.persisted? && business&.persisted?
      tokens = JwtService.generate_tokens(user)
      { success: true, user: user, business: business, tokens: tokens }
    else
      { success: false, errors: @errors }
    end
  end

  private

  def normalize_opening_hours(hours)
    return {} if hours.blank?

    ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].index_with do |day|
      day_hours = hours[day] || hours[day.to_sym]
      next [] if day_hours.blank?

      intervals = Array(day_hours).filter_map do |h|
        next unless h.is_a?(Hash)

        open_val = h["open"].presence || h[:open].presence
        close_val = h["close"].presence || h[:close].presence
        { "open" => open_val.to_s, "close" => close_val.to_s } if open_val.present? && close_val.present?
      end

      # Legacy: single hash { open, close } for the day
      if intervals.empty? && day_hours.is_a?(Hash)
        open_val = day_hours["open"].presence || day_hours[:open].presence
        close_val = day_hours["close"].presence || day_hours[:close].presence
        intervals = [{ "open" => open_val.to_s, "close" => close_val.to_s }] if open_val.present? && close_val.present?
      end

      intervals
    end
  end
end
