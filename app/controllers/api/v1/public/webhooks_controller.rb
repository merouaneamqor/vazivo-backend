# frozen_string_literal: true

module Api
  module V1
    module Public
      class WebhooksController < BaseController
            # POST /api/v1/webhooks/stripe
            def stripe
              payload = request.body.read
              sig_header = request.env['HTTP_STRIPE_SIGNATURE']
              endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

          begin
            event = Stripe::Webhook.construct_event(
              payload, sig_header, endpoint_secret
            )
          rescue JSON::ParserError
            return render json: { error: "Invalid payload" }, status: :bad_request
          rescue Stripe::SignatureVerificationError
            return render json: { error: "Invalid signature" }, status: :bad_request
          end

          # Handle the event
          case event.type
          when "payment_intent.succeeded"
            handle_payment_succeeded(event.data.object)
          when "payment_intent.payment_failed"
            handle_payment_failed(event.data.object)
          when "invoice.paid"
            handle_invoice_paid(event.data.object)
          when "checkout.session.completed"
            handle_checkout_completed(event.data.object)
          else
            Rails.logger.info "Unhandled Stripe event type: #{event.type}"
          end

          render json: { received: true }
        end

        private

        # ── Booking payments (customer payments for bookings) ─────────────────
        def handle_payment_succeeded(payment_intent)
          payment = BookingPayment.find_by(stripe_payment_intent_id: payment_intent.id)
          return unless payment

          payment.mark_as_paid!
          payment.booking.confirm! if payment.booking.status_pending?

          # TODO: Send confirmation email
          # BookingMailer.confirmation(payment.booking).deliver_later
        end

        def handle_payment_failed(payment_intent)
          payment = BookingPayment.find_by(stripe_payment_intent_id: payment_intent.id)
          return unless payment

          payment.mark_as_failed!
        end

        # ── Premium provider subscription payments (per business) ─────────────
        def handle_invoice_paid(invoice)
          return unless invoice.metadata&.dig("type") == "provider_premium"

          business = resolve_business_from_metadata(invoice.metadata)
          return unless business

          upgrade_provider(
            business: business,
            payment_reference: invoice.id,
            amount: (invoice.amount_paid || 0) / 100.0,
            currency: invoice.currency || "mad",
            paid_via: "stripe",
            plan_id: invoice.metadata["plan_id"] || "premium_monthly",
            expires_at: parse_expiry(invoice.metadata["expires_at"])
          )
        end

        def handle_checkout_completed(session)
          return unless session.metadata&.dig("type") == "provider_premium"

          business = resolve_business_from_metadata(session.metadata)
          return unless business

          upgrade_provider(
            business: business,
            payment_reference: session.payment_intent || session.id,
            amount: (session.amount_total || 0) / 100.0,
            currency: session.currency || "mad",
            paid_via: "stripe",
            plan_id: session.metadata["plan_id"] || "premium_monthly",
            expires_at: parse_expiry(session.metadata["expires_at"])
          )
        end

        def resolve_business_from_metadata(metadata)
          if metadata["business_id"].present?
            Business.find_by(id: metadata["business_id"])
          elsif metadata["user_id"].present?
            user = User.find_by(id: metadata["user_id"])
            user&.provider? ? user.businesses.kept.order(:id).first : nil
          end
        end

        def upgrade_provider(business:, payment_reference:, amount:, currency:, paid_via:, plan_id:, expires_at:)
          result = ProviderPremiumUpgradeService.new.call(
            business: business,
            expires_at: expires_at,
            paid_via: paid_via,
            amount: amount,
            currency: currency,
            plan_id: plan_id,
            payment_reference: payment_reference
          )

          if result[:success]
            Rails.logger.info "[Webhook] Business ##{business.id} upgraded to premium until #{expires_at}"
          else
            Rails.logger.error "[Webhook] Failed to upgrade business ##{business.id}: #{Array(result[:errors]).join(', ')}"
          end
        end

        def parse_expiry(value)
          return 1.month.from_now if value.blank?

          Time.zone.parse(value.to_s)
        rescue ArgumentError
          1.month.from_now
        end
      end
    end
  end
end
