# frozen_string_literal: true

module Api
  module V1
    module Admin
      class DashboardController < BaseController
        def index
          today = Time.zone.today
          kpis = calculate_kpis(today)
          charts = calculate_charts(today)
          recent_activity = fetch_recent_activity

          render json: { kpis: kpis, charts: charts, recent_activity: recent_activity }
        end

        private

        def calculate_kpis(today)
          {
            bookings_today: Booking.where(date: today).count,
            bookings_yesterday: Booking.where(date: today - 1.day).count,
            revenue_today: ProviderInvoice.paid.where("DATE(paid_at) = ?", today).sum(:total).to_f,
            revenue_yesterday: ProviderInvoice.paid.where("DATE(paid_at) = ?", today - 1.day).sum(:total).to_f,
            active_providers: Business.kept.count,
            pending_provider_approvals: Business.kept.joins(:user).where(users: { provider_status: "not_confirmed" }).count,
            new_customers_week: ::User.customers.where(created_at: today.beginning_of_week..).count,
            new_customers_last_week: ::User.customers.where(created_at: (today.beginning_of_week - 7.days)...today.beginning_of_week).count,
            total_bookings_month: Booking.where(date: today.beginning_of_month..).count,
            total_revenue_month: ProviderInvoice.paid.where(paid_at: today.beginning_of_month..).sum(:total).to_f,
            premium_providers: Business.kept.where("premium_expires_at > ?", Time.current).count,
            verified_providers: Business.kept.where(verification_status: "verified").count,
            active_subscriptions: Subscription.where(status: "active").where("expires_at > ?", Time.current).count,
            subscriptions_by_plan: Subscription.where(status: "active").where("expires_at > ?", Time.current).group(:plan_id).count,
            mrr: calculate_mrr.to_f,
            new_subscriptions_month: Subscription.where(started_at: today.beginning_of_month..).count,
          }
        end

        def calculate_mrr
          mrr_sum = ProviderInvoice.paid.joins(:subscription).where(subscriptions: { status: "active" })
                                    .where("subscriptions.expires_at > ?", Time.current)
                                    .where(provider_invoices: { paid_at: 30.days.ago.. }).sum(:total) || 0
          (mrr_sum.to_d / 30.0 * 30).to_f
        end

        def calculate_charts(today)
          {
            bookings_by_day: chart_bookings_by_day(today),
            revenue_by_day: chart_revenue_by_day,
            reviews_by_day: chart_reviews_by_day,
            new_customers_by_day: chart_new_customers_by_day(today),
            bookings_by_status: chart_bookings_by_status,
            rating_distribution: chart_rating_distribution,
            top_cities: chart_top_cities,
            top_categories: chart_top_categories,
          }
        end

        def chart_bookings_by_day(today)
          Booking.where(date: (today - 30.days)..).group(:date).count.transform_keys(&:to_s)
        end

        def chart_revenue_by_day
          ProviderInvoice.paid.where(paid_at: 30.days.ago..).group("DATE(paid_at)").sum(:total).transform_keys(&:to_s).transform_values(&:to_f)
        end

        def chart_reviews_by_day
          Review.where(created_at: 30.days.ago..).group("DATE(created_at)").count.transform_keys(&:to_s).transform_values(&:to_i)
        end

        def chart_new_customers_by_day(today)
          ::User.customers.where(created_at: (today - 30.days).to_date..).group("DATE(created_at)").count.transform_keys(&:to_s).transform_values(&:to_i)
        end

        def chart_bookings_by_status
          Booking.group(:status).count.transform_keys(&:to_s).transform_values(&:to_i)
        end

        def chart_rating_distribution
          (1..5).index_with { |r| Review.where(rating: r).count }.transform_keys(&:to_s).transform_values(&:to_i)
        end

        def chart_top_cities
          Business.kept.group(:city).count.sort_by { |_, v| -v }.first(10).map { |k, v| { name: chart_label(k), value: v } }
        end

        def chart_top_categories
          Business.kept.group(:category).count.sort_by { |_, v| -v }.first(10).map { |k, v| { name: chart_label(k), value: v } }
        end

        def fetch_recent_activity
          {
            bookings: Booking.includes(:user, :services, :business).order(created_at: :desc).limit(10).map { |b| booking_activity_item(b) },
            reviews: Review.includes(:user, :business).order(created_at: :desc).limit(10).map { |r| review_activity_item(r) },
          }
        end

        def chart_label(key)
          return "—" if key.nil?
          return key.to_s if key.is_a?(String) || key.is_a?(Numeric)

          key.respond_to?(:name) ? key.name.to_s : key.to_s
        end

        def booking_activity_item(booking)
          {
            id: booking.id,
            type: "booking",
            customer_name: safe_translated(booking.user, :name),
            business_name: safe_translated(booking.business, :translated_name),
            service_name: safe_translated(booking.services.first, :translated_name),
            date: booking.date,
            status: booking.status,
            created_at: booking.created_at,
          }
        end

        def review_activity_item(review)
          {
            id: review.id,
            type: "review",
            user_name: safe_translated(review.user, :name),
            business_name: safe_translated(review.business, :translated_name),
            rating: review.rating,
            created_at: review.created_at,
          }
        end

        def safe_translated(record, method)
          return nil if record.nil?

          record.public_send(method)
        rescue StandardError
          nil
        end
      end
    end
  end
end
