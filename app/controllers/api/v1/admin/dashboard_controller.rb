# frozen_string_literal: true

module Api
  module V1
    module Admin
      class DashboardController < BaseController
        def index
          today = Time.zone.today
          yesterday = today - 1.day
          week_start = today.beginning_of_week
          last_week_start = week_start - 7.days
          month_start = today.beginning_of_month
          1.month

          bookings_today = Booking.where(date: today).count
          bookings_yesterday = Booking.where(date: yesterday).count
          revenue_today = ProviderInvoice.paid.where("DATE(paid_at) = ?", today).sum(:total)
          revenue_yesterday = ProviderInvoice.paid.where("DATE(paid_at) = ?", yesterday).sum(:total)
          active_providers = Business.kept.count
          pending_providers = Business.kept.joins(:user).where(users: { provider_status: "not_confirmed" }).count
          new_customers_week = ::User.customers.where(created_at: week_start..).count
          new_customers_last_week = ::User.customers.where(created_at: last_week_start...week_start).count
          total_bookings_month = Booking.where(date: month_start..).count
          total_revenue_month = ProviderInvoice.paid.where(paid_at: month_start..).sum(:total)
          premium_providers = Business.kept.where("premium_expires_at > ?", Time.current).count
          verified_providers = Business.kept.where(verification_status: "verified").count

          active_subscriptions = Subscription.where(status: "active").where("expires_at > ?", Time.current).count
          subscriptions_by_plan = Subscription.where(status: "active").where("expires_at > ?",
                                                                             Time.current).group(:plan_id).count
          mrr_sum = ProviderInvoice.paid.joins(:subscription).where(subscriptions: { status: "active" }).where(
            "subscriptions.expires_at > ?", Time.current
          ).where(provider_invoices: { paid_at: 30.days.ago.. }).sum(:total) || 0
          mrr = (mrr_sum.to_d / 30.0 * 30).to_f
          new_subscriptions_month = Subscription.where(started_at: month_start..).count

          bookings_by_day = Booking.where(date: (today - 30.days)..).group(:date).count
          revenue_by_day = ProviderInvoice.paid.where(paid_at: 30.days.ago..).group("DATE(paid_at)").sum(:total)
          reviews_by_day = Review.where(created_at: 30.days.ago..).group("DATE(created_at)").count
          new_customers_by_day = ::User.customers.where(created_at: (today - 30.days).to_date..).group("DATE(created_at)").count
          bookings_by_status = Booking.group(:status).count
          rating_distribution = Review.group(:rating).count
          top_cities = Business.kept.group(:city).count.sort_by { |_, v| -v }.first(10)
          top_categories = Business.kept.group(:category).count.sort_by { |_, v| -v }.first(10)

          recent_bookings = Booking.includes(:user, :services, :business).order(created_at: :desc).limit(10)
          recent_reviews = Review.includes(:user, :business).order(created_at: :desc).limit(10)

          render json: {
            kpis: {
              bookings_today: bookings_today,
              bookings_yesterday: bookings_yesterday,
              revenue_today: revenue_today.to_f,
              revenue_yesterday: revenue_yesterday.to_f,
              active_providers: active_providers,
              pending_provider_approvals: pending_providers,
              new_customers_week: new_customers_week,
              new_customers_last_week: new_customers_last_week,
              total_bookings_month: total_bookings_month,
              total_revenue_month: total_revenue_month.to_f,
              premium_providers: premium_providers,
              verified_providers: verified_providers,
              active_subscriptions: active_subscriptions,
              subscriptions_by_plan: subscriptions_by_plan,
              mrr: mrr.to_f,
              new_subscriptions_month: new_subscriptions_month,
            },
            charts: {
              bookings_by_day: bookings_by_day.transform_keys(&:to_s),
              revenue_by_day: revenue_by_day.transform_keys(&:to_s).transform_values(&:to_f),
              reviews_by_day: reviews_by_day.transform_keys(&:to_s).transform_values(&:to_i),
              new_customers_by_day: new_customers_by_day.transform_keys(&:to_s).transform_values(&:to_i),
              bookings_by_status: bookings_by_status.transform_keys(&:to_s).transform_values(&:to_i),
              rating_distribution: (1..5).index_with { |r| rating_distribution[r] || 0 }.transform_keys(&:to_s).transform_values(&:to_i),
              top_cities: top_cities.map { |k, v| { name: chart_label(k), value: v } },
              top_categories: top_categories.map { |k, v| { name: chart_label(k), value: v } },
            },
            recent_activity: {
              bookings: recent_bookings.map { |b| booking_activity_item(b) },
              reviews: recent_reviews.map { |r| review_activity_item(r) },
            },
          }
        end

        private

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
