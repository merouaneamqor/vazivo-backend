# frozen_string_literal: true

module Api
  module V1
    module Admin
      class BookingsController < BaseController
        def index
          bookings = Booking.includes(:user, :services, :business)

          # Filters
          bookings = bookings.where(status: params[:status]) if params[:status].present?
          bookings = bookings.where(business_id: params[:provider_id]) if params[:provider_id].present?
          bookings = bookings.where(user_id: params[:customer_id]) if params[:customer_id].present?
          bookings = bookings.where(date: (params[:date_from])..) if params[:date_from].present?
          bookings = bookings.where(date: ..(params[:date_to])) if params[:date_to].present?

          # Search
          if params[:q].present?
            pattern = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
            bookings = bookings
              .left_joins(:user, :business)
              .left_joins(:services)
              .where(
                "users.name ILIKE :q OR businesses.name ILIKE :q OR services.name ILIKE :q OR bookings.customer_display_name ILIKE :q",
                q: pattern
              )
          end

          # Payment status filter
          if params[:payment_status].present?
            bookings = bookings.joins("LEFT JOIN booking_payments ON booking_payments.booking_id = bookings.id")
              .where(booking_payments: { status: params[:payment_status] })
          end

          bookings = bookings.order(created_at: :desc)
          @pagy, bookings = pagy(bookings.distinct, items: params[:per_page] || 20)

          items = bookings.map { |b| booking_list_item(b) }
          render json: { bookings: items, meta: pagination_meta }
        end

        def show
          booking = Booking.includes(:user, :services, :business, :review,
                                     booking_service_items: :staff).find(params[:id])
          payment = BookingPayment.find_by(booking_id: booking.id)
          customer_json = if booking.user
                            UserSerializer.new(booking.user).as_json
                          else
                            { name: booking.customer_display_name, email: booking.customer_email,
                              phone: booking.customer_phone }
                          end
          primary_item = booking.booking_service_items.first

          render json: {
            booking: booking_detail(booking),
            customer: customer_json,
            provider: BusinessSerializer.new(booking.business).as_json,
            service: if primary_item&.service
                       {
                         id: primary_item.service.id,
                         name: primary_item.service.translated_name,
                         price: primary_item.price,
                         duration: primary_item.duration_minutes,
                       }
                     end,
            payment: if payment
                       { id: payment.id, amount: payment.amount, status: payment.status,
                         paid_at: payment.paid_at }
                     end,
          }
        end

        def update
          booking = Booking.find(params[:id])
          if booking.update(booking_params)
            log_admin_action(:update, "Booking", booking.id, details: { message: "Updated booking ##{booking.id}" },
                                                             update_resource: booking)
            render json: { booking: booking_detail(booking) }
          else
            render_errors(booking.errors.full_messages)
          end
        end

        def cancel
          booking = Booking.find(params[:id])
          booking.update!(status: "cancelled", cancelled_at: Time.current)
          log_admin_action(:cancel, "Booking", booking.id, details: { message: "Cancelled booking ##{booking.id}" })
          render json: { message: "Booking cancelled", booking: booking_detail(booking) }
        end

        def refund
          booking = Booking.find(params[:id])
          payment = BookingPayment.find_by(booking_id: booking.id)
          if payment
            payment.update!(status: "refunded", refunded_at: Time.current)
            log_admin_action(:refund, "Booking", booking.id,
                             details: { message: "Refunded payment for booking ##{booking.id}" })
            render json: { message: "Refund processed", payment: { id: payment.id, status: payment.status } }
          else
            render json: { error: "No payment found" }, status: :unprocessable_content
          end
        end

        private

        def booking_params
          params.require(:booking).permit(:date, :start_time, :end_time, :status, :notes)
        end

        def booking_list_item(b)
          primary_item = b.booking_service_items.first

          {
            id: b.id,
            user_id: b.user_id,
            customer_name: b.customer_display_name,
            business_id: b.business_id,
            business_name: b.business&.translated_name,
            service_id: primary_item&.service_id,
            service_name: primary_item&.service&.translated_name,
            date: b.date,
            start_time: b.start_time&.strftime("%H:%M"),
            end_time: b.end_time&.strftime("%H:%M"),
            status: b.status,
            total_price: b.total_price&.to_f,
            payment_status: BookingPayment.find_by(booking_id: b.id)&.status,
            created_at: b.created_at,
          }
        end

        def booking_detail(b)
          primary_item = b.booking_service_items.first

          {
            id: b.id,
            user_id: b.user_id,
            customer_name: b.customer_display_name,
            business_id: b.business_id,
            service_id: primary_item&.service_id,
            date: b.date,
            start_time: b.start_time&.strftime("%H:%M"),
            end_time: b.end_time&.strftime("%H:%M"),
            status: b.status,
            total_price: b.total_price&.to_f,
            notes: b.notes,
            confirmed_at: b.confirmed_at,
            cancelled_at: b.cancelled_at,
            completed_at: b.completed_at,
            created_at: b.created_at,
            updated_at: b.updated_at,
          }
        end
      end
    end
  end
end
