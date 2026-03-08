# frozen_string_literal: true

module Api
  module V1
    module Provider
      class DashboardController < BaseController
        # GET /api/v1/provider/dashboard
        def index
          render json: {
            businesses: serialize_businesses(current_user_businesses),
            stats: aggregate_stats(current_user_businesses),
          }
        end

        # GET /api/v1/provider/stats
        def stats
          render json: aggregate_stats(current_user_businesses)
        end

        # GET /api/v1/provider/bookings
        def bookings
          business = params[:business_id].present? ? find_accessible_business(params[:business_id]) : nil

          bookings = if business
                       business.bookings
                     else
                       Booking.where(business_id: current_user_businesses.select(:id))
                     end

          bookings = bookings.includes(:user, :service, :staff, :business)
            .order(date: :desc, start_time: :desc)

          bookings = bookings.for_staff(params[:user_id]) if params[:user_id].present?

          if params[:start_date] && params[:end_date]
            bookings = bookings.for_date_range(params[:start_date],
                                               params[:end_date])
          end
          bookings = bookings.where(status: params[:status]) if params[:status]

          render json: { bookings: bookings.map { |b| BookingSerializer.new(b).as_json } }
        end

        # GET /api/v1/provider/calendar
        def calendar
          business_id = params[:business_id]
          start_date = params[:start_date] || Date.current.to_s
          end_date = params[:end_date] || (Date.current + 30.days).to_s

          bookings = if business_id
                       Business.find(business_id).bookings
                     else
                       Booking.where(business_id: current_user_businesses.select(:id))
                     end

          bookings = bookings.for_date_range(start_date, end_date)
            .includes(:services, :user, :staff, booking_service_items: :service)

          events = bookings.map do |booking|
            primary_service = booking.services.first || booking.booking_service_items.first&.service
            service_name = primary_service&.translated_name || primary_service&.category_name || "Service"
            {
              id: booking.id,
              title: "#{service_name} - #{booking.customer_name}",
              start: "#{booking.date}T#{booking.start_time.strftime('%H:%M:%S')}",
              end: booking.end_time ? "#{booking.date}T#{booking.end_time.strftime('%H:%M:%S')}" : nil,
              status: booking.status,
              customer_name: booking.customer_name,
              service_name: service_name,
              staff_name: booking.staff&.name,
              total_price: booking.total_price,
            }
          end

          render json: { events: events }
        end

        private

        def serialize_businesses(businesses)
          businesses.map { |b| BusinessPresenter.new(b).as_json }
        end

        def aggregate_stats(businesses)
          business_ids = businesses.select(:id)
          {
            total_businesses: businesses.count,
            total_bookings: Booking.where(business_id: business_ids).count,
            pending_bookings: Booking.where(business_id: business_ids, status: "pending").count,
            total_revenue: Booking.where(business_id: business_ids, status: "completed").sum(:total_price),
            total_reviews: Review.where(business_id: business_ids).count,
          }
        end

        def find_accessible_business(id)
          current_user_businesses.find(id)
        end
      end
    end
  end
end
