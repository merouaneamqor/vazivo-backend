# frozen_string_literal: true

module Api
  module V1
    module Customer
      class ReviewsController < BaseController
        before_action :authenticate_user!, except: [:index, :show, :create_public]
        before_action :set_business, only: [:index]
        before_action :set_review, only: [:show, :update, :destroy]

        # GET /api/v1/businesses/:business_id/reviews
        def index
          reviews = @business.reviews
            .approved
            .includes(:user, :booking)
            .recent

          reviews = reviews.by_rating(params[:rating]) if params[:rating]
          reviews = reviews.with_photos if params[:with_photos] == "true"

          @pagy, reviews = pagy(reviews, items: params[:per_page] || 20)

          render json: {
            reviews: ActiveModelSerializers::SerializableResource.new(
              reviews,
              each_serializer: ReviewSerializer
            ),
            meta: pagination_meta.merge(
              average_rating: @business.average_rating,
              total_reviews: @business.total_reviews,
              rating_breakdown: calculate_rating_breakdown(@business),
              category_averages: calculate_category_averages(@business)
            ),
          }
        end

        # GET /api/v1/businesses/:business_id/reviews/summary
        def summary
          set_business

          render json: {
            average_rating: @business.average_rating,
            total_reviews: @business.total_reviews,
            rating_breakdown: calculate_rating_breakdown(@business),
            category_averages: calculate_category_averages(@business),
            recent_photos: recent_review_photos(@business),
          }
        end

        # GET /api/v1/reviews/:id
        def show
          authorize @review
          render json: @review, serializer: ReviewSerializer
        end

        # POST /api/v1/reviews
        def create
          @review = current_user.reviews.build(review_params)
          authorize @review

          if @review.save
            render json: @review, serializer: ReviewSerializer, status: :created
          else
            render_errors(@review.errors.full_messages)
          end
        end

        # POST /api/v1/reviews/public (for QR code reviews without booking)
        def create_public
          business = Business.kept.find_by(id: params[:review][:business_id])
          return render_error("Business not found", :not_found) unless business

          @review = Review.new(review_params.except(:booking_id))
          @review.business = business
          @review.user_id = current_user&.id # Optional if logged in
          @review.booking_id = nil # No booking required for QR reviews

          # Skip booking validations for public reviews
          @review.save(validate: false)
          @review.validate # Run other validations

          if @review.errors.empty? && @review.persisted?
            render json: @review, serializer: ReviewSerializer, status: :created
          else
            render_errors(@review.errors.full_messages)
          end
        end

        # PATCH /api/v1/reviews/:id
        def update
          authorize @review

          if @review.update(update_review_params)
            render json: @review, serializer: ReviewSerializer
          else
            render_errors(@review.errors.full_messages)
          end
        end

        # DELETE /api/v1/reviews/:id
        def destroy
          authorize @review
          @review.destroy
          head :no_content
        end

        private

        def set_business
          @business = Business.kept.find(params[:business_id])
        end

        def set_review
          @review = Review.find(params[:id])
        end

        def review_params
          params.require(:review).permit(
            :booking_id, :rating, :comment,
            :cleanliness_rating, :punctuality_rating, :professionalism_rating,
            :service_quality_rating, :hygiene_rating,
            :ambiance_rating, :staff_friendliness_rating, :waiting_time_rating, :value_rating,
            photos: []
          )
        end

        def update_review_params
          params.require(:review).permit(:rating, :comment, photos: [])
        end

        def calculate_rating_breakdown(business)
          reviews = business.reviews.approved
          total = reviews.count
          return {} if total.zero?

          (1..5).to_h do |rating|
            count = reviews.where(rating: rating).count
            [rating, { count: count, percentage: (count.to_f / total * 100).round(1) }]
          end
        end

        def calculate_category_averages(business)
          reviews = business.reviews.approved
          return {} if reviews.empty?

          Review::CORE_CATEGORIES.to_h do |category|
            avg = reviews.average("#{category}_rating").to_f.round(2)
            [category, avg]
          end.merge(
            Review::PREMIUM_CATEGORIES.to_h do |category|
              avg = reviews.where.not("#{category}_rating": nil).average("#{category}_rating").to_f.round(2)
              [category, avg]
            end
          )
        end

        def recent_review_photos(business)
          business.reviews.approved.with_photos.recent.limit(12).flat_map(&:photos).take(12)
        end
      end
    end
  end
end
