# frozen_string_literal: true

module Api
  module V1
    module Provider
      class ReviewsController < BaseController
        def index
          business_id = params[:business_id] || current_user.businesses.first&.id
          return render json: { error: "No business found" }, status: :not_found unless business_id

          business = current_user.businesses.find_by(id: business_id)
          return render json: { error: "Business not found" }, status: :not_found unless business

          reviews = Review.left_joins(:user, :booking)
            .where(business_id: business.id)
            .approved
            .includes(:user, booking: { booking_service_items: :service })

          # Apply filters
          reviews = reviews.where(rating: params[:rating]) if params[:rating].present?
          if params[:q].present?
            query = "%#{params[:q].downcase}%"
            reviews = reviews.where("LOWER(users.name) LIKE ? OR LOWER(reviews.comment) LIKE ?", query, query)
          end

          reviews = reviews.order(created_at: :desc)

          # Calculate stats
          all_reviews = Review.where(business_id: business.id).approved
          stats = {
            total_reviews: all_reviews.count,
            average_rating: all_reviews.average(:rating)&.to_f&.round(1) || 0.0,
            rating_distribution: all_reviews.group(:rating).count,
            response_rate: calculate_response_rate(all_reviews),
            category_averages: calculate_category_averages(all_reviews, business.premium?),
          }

          render json: {
            reviews: reviews.map { |r| serialize_review(r) },
            stats: stats,
          }
        end

        def respond
          review = Review.find(params[:id])
          business_ids = current_user.businesses.pluck(:id)

          unless business_ids.include?(review.business_id)
            return render json: { error: "Unauthorized" },
                          status: :forbidden
          end

          review.update!(
            response: params[:response],
            responded_at: Time.current
          )

          render json: { message: "Response posted", review: serialize_review(review) }
        end

        def moderate
          review = Review.find(params[:id])
          business_ids = current_user.businesses.pluck(:id)

          unless business_ids.include?(review.business_id)
            return render json: { error: "Unauthorized" },
                          status: :forbidden
          end

          review.update!(moderation_status: params[:status])

          render json: { message: "Review moderated", review: serialize_review(review) }
        end

        private

        def serialize_review(review)
          {
            id: review.id,
            customer_name: review.user&.name || "Anonymous",
            customer_avatar: review.user&.avatar_url,
            rating: review.rating || 0,
            comment: review.comment || "",
            service_name: review.booking&.booking_service_items&.first&.service&.translated_name || "Unknown",
            booking_date: review.booking&.start_time&.iso8601,
            created_at: review.created_at&.iso8601,
            edited_at: review.edited_at&.iso8601,
            response: review.response,
            responded_at: review.responded_at&.iso8601,
            # Multi-criteria ratings
            cleanliness_rating: review.cleanliness_rating,
            punctuality_rating: review.punctuality_rating,
            professionalism_rating: review.professionalism_rating,
            service_quality_rating: review.service_quality_rating,
            hygiene_rating: review.hygiene_rating,
            ambiance_rating: review.ambiance_rating,
            staff_friendliness_rating: review.staff_friendliness_rating,
            waiting_time_rating: review.waiting_time_rating,
            value_rating: review.value_rating,
            photos: review.photos || [],
            moderation_status: review.moderation_status,
          }
        end

        def calculate_response_rate(reviews)
          total = reviews.count
          return 0 if total.zero?

          responded = reviews.where.not(response: nil).count
          ((responded.to_f / total) * 100).round
        end

        def calculate_category_averages(reviews, is_premium)
          return {} if reviews.empty?

          averages = Review::CORE_CATEGORIES.to_h do |category|
            avg = reviews.average("#{category}_rating").to_f.round(2)
            [category, avg]
          end

          if is_premium
            averages.merge!(
              Review::PREMIUM_CATEGORIES.to_h do |category|
                avg = reviews.where.not("#{category}_rating": nil).average("#{category}_rating").to_f.round(2)
                [category, avg]
              end
            )
          end

          averages
        end
      end
    end
  end
end
