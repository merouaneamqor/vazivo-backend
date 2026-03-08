# frozen_string_literal: true

module Api
  module V1
    module Public
      class BusinessesController < ApplicationController
        # Public controller - no authentication required
        # Authentication is opt-in via authenticate_user! method, not a before_action

        # GET /api/v1/public/businesses
        # List all active businesses with optional filters (only confirmed providers)
        def index
          businesses = public_businesses_scope
            .includes(:user, :services, :reviews)

          businesses = businesses.premium if params[:premium] == "true"
          businesses = businesses.by_category(params[:category]) if params[:category].present?
          businesses = businesses.by_city(params[:city]) if params[:city].present?
          businesses = businesses.search(params[:q]) if params[:q].present?
          businesses = businesses.order(
            Arel.sql("businesses.premium_expires_at DESC NULLS LAST")
          ).order(created_at: :desc)

          @pagy, businesses = pagy(businesses, items: params[:limit] || params[:per_page] || 20)

          render json: {
            businesses: serialize_collection(businesses),
            meta: pagination_meta,
          }
        end

        # GET /api/v1/public/businesses/search
        # Advanced search with filters (price, rating, location)
        def search
          businesses = SearchService.new(search_params, base_scope: public_businesses_scope).search_businesses
          @pagy, businesses = pagy(businesses, items: params[:per_page] || 20)

          # Eager load after pagination to avoid GROUP BY conflicts
          preload_associations(businesses)

          meta = pagination_meta.merge(
            series: PaginationSeries.call(current_page: @pagy.page, total_pages: @pagy.pages)
          )
          render json: {
            businesses: serialize_collection(businesses),
            meta: meta,
          }
        end

        # GET /api/v1/public/businesses/:slug
        # Show business detail by slug (SEO-friendly)
        def show
          business = find_business!
          preload_associations([business])

          render json: {
            business: BusinessDetailPresenter.new(business).as_json,
          }
        end

        # GET /api/v1/public/businesses/:slug/services
        # List services for a business
        def services
          business = find_business!
          services = business.services.kept.includes(:service_category, { category: :parent })

          render json: {
            services: services.map { |s| ServicePresenter.new(s).as_json },
          }
        end

        # GET /api/v1/public/businesses/:slug/reviews
        # List reviews for a business with pagination
        def reviews
          business = find_business!
          reviews = business.reviews
            .includes(:user)
            .recent
          @pagy, reviews = pagy(reviews, items: params[:per_page] || 20)

          render json: {
            reviews: reviews.map { |r| ReviewPresenter.new(r).as_json },
            meta: pagination_meta,
          }
        end

        # GET /api/v1/public/businesses/:slug/availability
        # Next available time slots for this business (uses first service; set by business admin/provider).
        # Params: date (YYYY-MM-DD), end_date (optional, default date+6).
        def availability
          business = find_business!
          first_service = business.services.kept.order(:id).first
          return render json: { business_slug: business.translated_slug, calendar: [] } unless first_service

          start_date = parse_availability_date(params[:date], Date.current)
          end_date = parse_availability_date(params[:end_date], start_date + 6.days)
          end_date = start_date + 6.days if end_date < start_date

          availability_service = AvailabilityService.new(first_service)
          calendar = availability_service.availability_calendar(start_date, end_date)

          render json: {
            business_slug: business.translated_slug,
            service_id: first_service.id,
            calendar: calendar,
          }
        end

        # GET /api/v1/public/businesses/featured
        # Get featured/top-rated businesses
        def featured
          businesses = public_businesses_scope
            .includes(:user, :reviews)
            .joins(:reviews)
            .group("businesses.id")
            .having("AVG(reviews.rating) >= ?", 4.0)
            .order(
              Arel.sql("businesses.premium_expires_at DESC NULLS LAST")
            )
            .order("AVG(reviews.rating) DESC")
            .limit(params[:limit] || 10)

          render json: {
            businesses: serialize_collection(businesses),
          }
        end

        # GET /api/v1/public/businesses/nearby
        # Get businesses near a location
        def nearby
          return render_error("Location required", :bad_request) unless params[:lat] && params[:lng]

          businesses = public_businesses_scope
            .includes(:user, :reviews)
            .near(params[:lat], params[:lng], params[:radius] || 10)
            .limit(params[:limit] || 20)

          render json: {
            businesses: serialize_collection(businesses),
          }
        end

        # POST /api/v1/public/businesses/:slug/claim
        # Submit a claim request for this business (owner verification). No auth required.
        def claim
          business = Business.kept.find_by!(slug: params[:slug])
          req = business.business_claim_requests.build(claim_params)
          req.user_id = current_user.id if current_user.present?
          if req.save
            render json: { message: "Claim request submitted. We'll be in touch shortly." }, status: :created
          else
            render json: { errors: req.errors.full_messages }, status: :unprocessable_content
          end
        rescue ActiveRecord::RecordNotFound
          render json: { error: "Business not found" }, status: :not_found
        end

        # Tracking methods (public actions)
        def track_phone_click
          business = Business.find(params[:id])
          BusinessStatistic.increment_phone_clicks(business.id)
          render json: { message: "Phone click tracked" }, status: :ok
        end

        def track_profile_view
          business = Business.find(params[:id])
          BusinessStatistic.increment_profile_views(business.id)
          render json: { message: "Profile view tracked" }, status: :ok
        end

        def track_booking_click
          business = Business.find(params[:id])
          BusinessStatistic.increment_booking_clicks(business.id)
          render json: { message: "Booking click tracked" }, status: :ok
        end

        def track_google_maps_click
          business = Business.find(params[:id])
          BusinessStatistic.increment_google_maps_clicks(business.id)
          render json: { message: "Google Maps click tracked" }, status: :ok
        end

        def track_waze_click
          business = Business.find(params[:id])
          BusinessStatistic.increment_waze_clicks(business.id)
          render json: { message: "Waze click tracked" }, status: :ok
        end

        private

        def public_businesses_scope
          Business.kept.confirmed_provider
        end

        def find_business!
          identifier = (params[:slug] || params[:id]).to_s.strip
          raise ActiveRecord::RecordNotFound if identifier.blank?

          # Support both numeric ID (legacy) and slug (SEO-friendly); only confirmed providers
          return public_businesses_scope.find(identifier) if identifier.match?(/\A\d+\z/)

          business = public_businesses_scope.find_by(slug: identifier)
          # Fallback: if slug is "name-city" (e.g. gym-fit-agadir-agadir), try "name" (gym-fit-agadir) in case DB has older slug
          if business.nil? && identifier.include?("-")
            fallback_slug = identifier.sub(/-[a-z0-9-]+\z/, "")
            if fallback_slug.present? && fallback_slug != identifier
              business = public_businesses_scope.find_by(slug: fallback_slug)
            end
          end
          raise ActiveRecord::RecordNotFound if business.nil?

          business
        end

        def search_params
          params.permit(
            :q, :category, :cuisine, :city,
            :min_price, :max_price, :min_rating,
            :lat, :lng, :radius,
            :sort_by, :page, :per_page
          )
        end

        def preload_associations(records)
          ActiveRecord::Associations::Preloader.new(
            records: records,
            associations: [
              :user, :services, :reviews,
              { business_staff: :user }
            ]
          ).call
        end

        def serialize_collection(businesses)
          businesses.map { |b| BusinessPresenter.new(b).as_json }
        end

        def parse_availability_date(value, default)
          return default if value.blank?

          parsed = Date.parse(value.to_s)
          [parsed, Date.current].max
        rescue ArgumentError, TypeError
          default
        end

        def claim_params
          params.require(:claim_request).permit(:name, :email, :message)
        end
      end
    end
  end
end
