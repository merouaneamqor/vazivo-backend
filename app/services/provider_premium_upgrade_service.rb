# frozen_string_literal: true

# Upgrades a provider business to premium by creating a Subscription + ProviderInvoice
# and syncing Business#premium_expires_at.
class ProviderPremiumUpgradeService
  def call(business:, expires_at:, paid_via:, amount:, currency:, plan_id:, payment_reference: nil, metadata: {})
    subscription = nil
    invoice = nil

    ActiveRecord::Base.transaction do
      now = Time.current

      subscription = business.subscriptions.create!(
        status: "active",
        plan_id: plan_id.presence || "premium_monthly",
        paid_via: paid_via.presence || "stripe",
        started_at: now,
        expires_at: expires_at
      )

      # Keep the furthest expiry.
      new_expiry = [business.premium_expires_at, expires_at].compact.max
      business.update!(premium_expires_at: new_expiry)

      invoice_metadata = (metadata || {}).dup
      invoice_metadata[:payment_reference] = payment_reference if payment_reference.present?

      invoice = ProviderInvoice.create!(
        business: business,
        subscription: subscription,
        invoice_id: ProviderInvoice.generate_invoice_id,
        total: amount,
        currency: currency.presence || "mad",
        status: "paid",
        payment_method: paid_via,
        paid_at: now,
        metadata: invoice_metadata.compact
      )
    end

    { success: true, business: business.reload, subscription: subscription, invoice: invoice }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, errors: e.record.errors.full_messages }
  rescue StandardError => e
    { success: false, errors: [e.message] }
  end
end
