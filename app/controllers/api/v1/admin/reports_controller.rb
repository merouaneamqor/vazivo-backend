# frozen_string_literal: true

module Api
  module V1
    module Admin
      class ReportsController < BaseController
        def index
          date_range = params[:range] || "30"
          start_date = date_range.to_i.days.ago
          compare_start = (date_range.to_i * 2).days.ago
          compare_end = date_range.to_i.days.ago

          # Revenue metrics
          revenue_current = ProviderInvoice.paid.where(paid_at: start_date..).sum(:total)
          revenue_previous = ProviderInvoice.paid.where(paid_at: compare_start...compare_end).sum(:total)
          revenue_by_day = ProviderInvoice.paid.where(paid_at: start_date..).group("DATE(paid_at)").sum(:total).transform_keys(&:to_s).transform_values(&:to_f)
          revenue_by_payment_method = ProviderInvoice.paid.where(paid_at: start_date..).group(:payment_method).sum(:total).transform_values(&:to_f)

          # Booking metrics
          bookings_current = Booking.where(date: start_date..).count
          bookings_previous = Booking.where(date: compare_start...compare_end).count
          bookings_by_day = Booking.where(date: start_date..).group(:date).count.transform_keys(&:to_s)
          bookings_by_status = Booking.where(date: start_date..).group(:status).count
          bookings_by_city = Booking.joins(:business).where(bookings: { date: start_date.. }).group("businesses.city").count.sort_by do |_, v|
            -v
          end.first(10)
          bookings_by_category = Booking.joins(:business).where(bookings: { date: start_date.. }).group("businesses.category").count.sort_by do |_, v|
            -v
          end.first(10)

          # Provider metrics
          new_providers = Business.where(created_at: start_date..).count
          active_providers = Business.kept.joins(:bookings).where(bookings: { date: start_date.. }).distinct.count
          top_providers = Business.kept.joins(:bookings).where(bookings: { date: start_date.. }).group("businesses.id",
                                                                                                       "businesses.name").count.sort_by do |_, v|
            -v
          end.first(10).map do |k, v|
            { id: k[0], name: k[1], bookings: v }
          end

          # Customer metrics
          new_customers = User.customers.where(created_at: start_date..).count
          active_customers = User.customers.joins(:bookings).where(bookings: { date: start_date.. }).distinct.count
          customer_retention = calculate_retention(start_date)

          # Subscription metrics
          new_subscriptions = Subscription.where(started_at: start_date..).count
          churned_subscriptions = Subscription.where("expires_at >= ? AND expires_at < ? AND status = ?", start_date,
                                                     Time.current, "expired").count
          subscription_revenue = ProviderInvoice.paid.joins(:subscription).where(provider_invoices: { paid_at: start_date.. }).sum(:total).to_f
          subscriptions_by_plan = Subscription.where(started_at: start_date..).group(:plan_id).count

          # Review metrics
          avg_rating = Review.where(created_at: start_date..).average(:rating).to_f.round(2)
          total_reviews = Review.where(created_at: start_date..).count
          reviews_by_rating = Review.where(created_at: start_date..).group(:rating).count

          render json: {
            date_range: date_range,
            revenue: {
              current: revenue_current.to_f,
              previous: revenue_previous.to_f,
              by_day: revenue_by_day,
              by_payment_method: revenue_by_payment_method,
            },
            bookings: {
              current: bookings_current,
              previous: bookings_previous,
              by_day: bookings_by_day,
              by_status: bookings_by_status,
              by_city: bookings_by_city.to_h,
              by_category: bookings_by_category.to_h,
            },
            providers: {
              new: new_providers,
              active: active_providers,
              top: top_providers,
            },
            customers: {
              new: new_customers,
              active: active_customers,
              retention_rate: customer_retention,
            },
            subscriptions: {
              new: new_subscriptions,
              churned: churned_subscriptions,
              revenue: subscription_revenue,
              by_plan: subscriptions_by_plan,
            },
            reviews: {
              average_rating: avg_rating,
              total: total_reviews,
              by_rating: reviews_by_rating,
            },
          }
        end

        def export
          # Placeholder: generate CSV/XLSX/PDF
          render json: { download_url: nil, message: "Export not implemented" }
        end

        private

        def calculate_retention(start_date)
          customers_start = User.customers.where(created_at: ...start_date).count
          return 0 if customers_start.zero?

          retained = User.customers.where(created_at: ...start_date).joins(:bookings).where(bookings: { date: start_date.. }).distinct.count
          ((retained.to_f / customers_start) * 100).round(2)
        end
      end
    end
  end
end
