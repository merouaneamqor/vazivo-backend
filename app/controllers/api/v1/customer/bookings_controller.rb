# frozen_string_literal: true

module Api
  module V1
    module Customer
      class BookingsController < BaseController
        before_action :authenticate_user!, except: [:create]
        before_action :set_booking, only: [:show, :update, :destroy, :confirm, :cancel, :complete]

        # GET /api/v1/bookings
        def index
          bookings = policy_scope(Booking)
            .includes(:services, :business, :user, booking_service_items: :staff)

          # Filters
          bookings = bookings.where(status: params[:status]) if params[:status]
          bookings = bookings.upcoming if params[:upcoming] == "true"
          bookings = bookings.past if params[:past] == "true"
          if params[:start_date] && params[:end_date]
            bookings = bookings.for_date_range(params[:start_date],
                                               params[:end_date])
          end

          @pagy, bookings = pagy(bookings.order(date: :desc, start_time: :desc), items: params[:per_page] || 20)

          render json: {
            bookings: bookings.map { |booking| BookingSerializer.new(booking).as_json },
            meta: pagination_meta,
          }
        end

        # GET /api/v1/bookings/:id
        def show
          authorize @booking
          render json: @booking, serializer: BookingDetailSerializer
        end

        # POST /api/v1/bookings (authenticated or guest)
        def create
          user = optional_current_user
          result = if user
                     first_service_id = booking_params[:services]&.dig(0,
                                                                       :service_id) || booking_params[:services]&.dig(
                                                                         0, "service_id"
                                                                       ) || booking_params[:service_id]
                     service = Service.kept.find_by(id: first_service_id)
                     provider_or_admin = service && (
                       service.business.user_id == user.id ||
                       user.admin? ||
                       (user.respond_to?(:can_access_admin?) && user.can_access_admin?)
                     )
                     # Provider/admin bookings always skip business hours check (allow booking even when closed)
                     skip_business_hours = provider_or_admin
                     ::BookingService.new(user).create(
                       booking_params,
                       skip_availability_check: provider_or_admin,
                       confirm_immediately: provider_or_admin,
                       skip_business_hours_check: skip_business_hours
                     )
                   else
                     ::BookingService.create_guest(booking_params)
                   end

          if result[:success]
            render json: result[:booking], serializer: BookingSerializer, status: :created
          else
            render_errors(result[:errors])
          end
        end

        # PATCH /api/v1/bookings/:id
        def update
          authorize @booking

          # Allow rescheduling
          if params[:booking][:date] || params[:booking][:start_time]
            service = BookingService.new(current_user)
            # Read skip flag from booking params
            skip_availability = params[:booking][:skip_availability_check].to_s == "true"
            result = service.reschedule(
              @booking,
              params[:booking][:date] || @booking.date,
              params[:booking][:start_time] || @booking.start_time.strftime("%H:%M"),
              skip_availability_check: skip_availability
            )

            if result[:success]
              render json: result[:booking], serializer: BookingSerializer
            else
              render_errors(result[:errors])
            end
          elsif @booking.update(update_params)
            render json: @booking, serializer: BookingSerializer
          else
            render_errors(@booking.errors.full_messages)
          end
        end

        # DELETE /api/v1/bookings/:id
        def destroy
          authorize @booking

          service = BookingService.new(current_user)
          result = service.cancel(@booking)

          if result[:success]
            render json: { message: "Booking cancelled successfully" }
          else
            render_errors(result[:errors])
          end
        end

        # POST /api/v1/bookings/:id/confirm
        def confirm
          authorize @booking

          service = BookingService.new(current_user)
          result = service.confirm(@booking)

          if result[:success]
            render json: result[:booking], serializer: BookingSerializer
          else
            render_errors(result[:errors])
          end
        end

        # POST /api/v1/bookings/:id/cancel
        def cancel
          authorize @booking

          service = BookingService.new(current_user)
          result = service.cancel(@booking)

          if result[:success]
            render json: result[:booking], serializer: BookingSerializer
          else
            render_errors(result[:errors])
          end
        end

        # POST /api/v1/bookings/:id/complete
        def complete
          authorize @booking

          service = BookingService.new(current_user)
          result = service.complete(@booking)

          if result[:success]
            render json: result[:booking], serializer: BookingSerializer
          else
            render_errors(result[:errors])
          end
        end

        private

        def set_booking
          @booking = Booking.find(params[:id])
        end

        def optional_current_user
          token = request.headers["Authorization"]&.split&.last.presence || cookies[:access_token]
          return nil unless token

          payload = JwtService.decode_access_token(token)
          ::User.kept.find_by(id: payload[:user_id])
        rescue JwtService::ExpiredToken, JwtService::InvalidToken
          nil
        end

        def booking_params
          params.require(:booking).permit(
            :service_id, :business_id, :staff_id, :date, :start_time, :end_time, :notes,
            :customer_name, :customer_first_name, :customer_last_name, :customer_phone, :customer_email, :client_id,
            :skip_availability_check, :skip_business_hours_check,
            services: [:service_id, :staff_id, :price, :duration_minutes]
          )
        end

        def update_params
          params.require(:booking).permit(:notes, :skip_availability_check, :skip_business_hours_check)
        end
      end
    end
  end
end
