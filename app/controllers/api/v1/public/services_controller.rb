# frozen_string_literal: true

module Api
  module V1
    module Public
      class ServicesController < ApplicationController
        # Public controller – no authentication required.
        # Uses the same models as provider booking: Service, Business, AvailabilityService.
        # Security: only services in bookable_services_scope are exposed (kept + confirmed business).

        # GET /api/v1/public/services/:id
        def show
          @service = find_bookable_service!
          render json: @service, serializer: ServiceDetailSerializer
        end

        # GET /api/v1/public/services/:id/availability
        def availability
          @service = find_bookable_service!
          date = params[:date] ? Date.parse(params[:date]) : Date.current
          end_date = params[:end_date] ? Date.parse(params[:end_date]) : date + 13.days

          availability_service = AvailabilityService.new(@service)

          if params[:date] && !params[:end_date]
            slots = availability_service.available_slots(date)
            render json: {
              date: date.to_s,
              service_id: @service.id,
              duration: @service.duration,
              slots: slots,
            }
          else
            calendar = availability_service.availability_calendar(date, end_date)
            render json: {
              service_id: @service.id,
              duration: @service.duration,
              calendar: calendar,
            }
          end
        rescue ArgumentError, TypeError
          render json: { error: "Invalid date" }, status: :bad_request
        end

        private

        def find_bookable_service!
          bookable_services_scope.includes(:business, :service_category).find(params[:id])
        end

        def bookable_services_scope
          Service
            .kept
            .joins(:business)
            .merge(Business.kept.confirmed_provider)
        end
      end
    end
  end
end
