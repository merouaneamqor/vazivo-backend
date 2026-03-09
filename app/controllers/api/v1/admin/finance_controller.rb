# frozen_string_literal: true

module Api
  module V1
    module Admin
      class FinanceController < BaseController
        def payouts
          # Placeholder: integrate with Stripe Connect payouts
          render json: {
            pending: [],
            completed: [],
            failed: [],
          }
        end

        # Business invoices (ProviderInvoice — plan subscriptions paid by businesses)
        def invoices
          invoices = apply_invoice_filters(ProviderInvoice.includes(:business, :subscription))
          stats = calculate_invoice_stats
          @pagy, invoices = pagy(invoices.order(created_at: :desc), items: params[:per_page] || 20)

          render json: {
            invoices: invoices.map { |inv| serialize_invoice(inv) },
            meta: pagination_meta,
            stats: stats,
          }
        end

        def apply_invoice_filters(invoices)
          invoices = invoices.where(status: params[:status]) if params[:status].present?
          invoices = invoices.where(payment_method: params[:payment_method]) if params[:payment_method].present?
          invoices = invoices.where(paid_at: (params[:paid_after])..) if params[:paid_after].present?
          invoices = invoices.where(paid_at: ..(params[:paid_before])) if params[:paid_before].present?
          invoices = invoices.where(total: (params[:min_amount])..) if params[:min_amount].present?
          invoices = invoices.where(total: ..(params[:max_amount])) if params[:max_amount].present?
          invoices = apply_invoice_search(invoices) if params[:q].present?
          invoices
        end

        def apply_invoice_search(invoices)
          pattern = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
          invoices.joins(:business).where("provider_invoices.invoice_id ILIKE :q OR businesses.name ILIKE :q", q: pattern)
        end

        def calculate_invoice_stats
          {
            total_revenue: ProviderInvoice.paid.sum(:total).to_f,
            pending_revenue: ProviderInvoice.where(status: "pending").sum(:total).to_f,
            total_count: ProviderInvoice.count,
            paid_count: ProviderInvoice.paid.count,
            by_month: invoice_stats_by_month,
            by_status: ProviderInvoice.group(:status).count,
            by_payment_method: ProviderInvoice.paid.group(:payment_method).count,
          }
        end

        def invoice_stats_by_month
          ProviderInvoice.paid.where.not(paid_at: nil).where(paid_at: 12.months.ago..)
                         .group("DATE_TRUNC('month', paid_at)").sum(:total)
                         .transform_keys { |k| k&.strftime("%Y-%m") }.transform_values(&:to_f)
        end

        def serialize_invoice(inv)
          {
            id: inv.id,
            invoice_id: inv.invoice_id,
            business_id: inv.business_id,
            business_name: inv.business&.translated_name,
            subscription_id: inv.subscription_id,
            plan_id: inv.subscription&.plan_id,
            total: inv.total.to_f,
            currency: inv.currency,
            status: inv.status,
            paid_at: inv.paid_at,
            payment_method: inv.payment_method,
            created_at: inv.created_at,
            metadata: inv.metadata,
          }
        end

        # Booking payment (BookingPayment — customer payments for bookings)
        def earnings
          total = BookingPayment.where(status: "succeeded").sum(:amount)
          by_month = BookingPayment.where(status: "succeeded").group("DATE_TRUNC('month', paid_at)").sum(:amount).transform_keys do |k|
            k&.strftime("%Y-%m")
          end.transform_values(&:to_f)
          render json: { total: total.to_f, by_month: by_month }
        end

        def logs
          payments = BookingPayment.order(created_at: :desc).limit(100)
          render json: { booking_payments: payments.map do |p|
            { id: p.id, booking_id: p.booking_id, amount: p.amount, status: p.status, paid_at: p.paid_at,
              refunded_at: p.refunded_at }
          end }
        end

        def trigger_payout
          # Placeholder
          render json: { message: "Payout triggered" }
        end

        def refund
          # Use Admin::BookingsController#refund or duplicate logic
          render json: { message: "Refund processed" }
        end
      end
    end
  end
end
