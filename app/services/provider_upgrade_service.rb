# frozen_string_literal: true

class ProviderUpgradeService
  def initialize(user)
    @user = user
  end

  def call(business_params:)
    ActiveRecord::Base.transaction do
      # Upgrade user role
      @user.update!(
        role: "provider",
        provider_status: "not_confirmed"
      )

      # Create business
      business = @user.businesses.create!(business_params)

      # Generate new tokens with updated role
      tokens = JwtService.generate_tokens(@user)

      # Send notifications
      UserMailer.provider_upgrade_confirmation(@user, business).deliver_later
      AdminMailer.new_provider_notification(@user, business).deliver_later if defined?(AdminMailer)

      {
        success: true,
        user: @user.reload,
        business:,
        tokens:,
      }
    end
  rescue ActiveRecord::RecordInvalid => e
    { success: false, errors: e.record.errors.full_messages }
  rescue StandardError => e
    { success: false, errors: [e.message] }
  end
end
