# frozen_string_literal: true

module Api
  module V1
    module Admin
      class ReviewsController < BaseController
        def index
          reviews = Review.includes(:user, :business)
          reviews = reviews.where(rating: params[:rating]) if params[:rating].present?
          reviews = reviews.where(business_id: params[:business_id]) if params[:business_id].present?
          reviews = reviews.where(user_id: params[:user_id]) if params[:user_id].present?
          reviews = reviews.where(moderation_status: params[:status]) if params[:status].present?
          reviews = reviews.order(created_at: :desc)
          @pagy, reviews = pagy(reviews, items: params[:per_page] || 20)

          items = reviews.map { |r| review_list_item(r) }
          render json: { reviews: items, meta: pagination_meta }
        end

        def show
          review = Review.includes(:user, :business, :booking).find(params[:id])
          render json: {
            review: review_list_item(review).merge(comment: review.comment),
            user: review.user ? UserSerializer.new(review.user).as_json : nil,
            business: review.business ? BusinessSerializer.new(review.business).as_json : nil,
          }
        end

        def update
          review = Review.find(params[:id])
          if review.update(review_params)
            log_admin_action(:update, "Review", review.id, details: { message: "Updated review ##{review.id}" },
                                                           update_resource: review)
            render json: { review: review_list_item(review).merge(comment: review.comment) }
          else
            render_errors(review.errors.full_messages)
          end
        end

        def moderate
          review = Review.find(params[:id])
          review.update!(
            moderation_status: params[:status],
            moderation_notes: params[:notes]
          )
          log_admin_action(:moderate, "Review", review.id, details: { message: "Moderated review ##{review.id}" })
          render json: { message: "Review moderated", review: review_list_item(review) }
        end

        def destroy
          review = Review.find(params[:id])
          review.destroy
          log_admin_action(:destroy, "Review", review.id, details: { message: "Deleted review ##{review.id}" })
          render json: { message: "Review deleted" }, status: :ok
        end

        def hide
          review = Review.find(params[:id])
          review.update!(hidden_at: Time.current)
          log_admin_action(:hide, "Review", review.id, details: { message: "Hidden review ##{review.id}" })
          render json: { message: "Review hidden", review: review_list_item(review) }
        end

        def unhide
          review = Review.find(params[:id])
          review.update!(hidden_at: nil)
          log_admin_action(:unhide, "Review", review.id, details: { message: "Unhidden review ##{review.id}" })
          render json: { message: "Review unhidden", review: review_list_item(review) }
        end

        def flag
          review = Review.find(params[:id])
          review.update!(
            flagged_at: Time.current,
            flag_reason: params[:reason]
          )
          log_admin_action(:flag, "Review", review.id, details: { message: "Flagged review ##{review.id}" })
          render json: { message: "Review flagged", review: review_list_item(review) }
        end

        def unflag
          review = Review.find(params[:id])
          review.update!(flagged_at: nil, flag_reason: nil)
          log_admin_action(:unflag, "Review", review.id, details: { message: "Unflagged review ##{review.id}" })
          render json: { message: "Review unflagged", review: review_list_item(review) }
        end

        private

        def review_params
          params.require(:review).permit(
            :rating, :comment,
            :cleanliness_rating, :punctuality_rating, :professionalism_rating,
            :service_quality_rating, :hygiene_rating,
            :ambiance_rating, :staff_friendliness_rating, :waiting_time_rating, :value_rating,
            :moderation_status, :moderation_notes,
            photos: []
          )
        end

        def review_list_item(r)
          {
            id: r.id,
            user_id: r.user_id,
            user_name: r.user&.name,
            business_id: r.business_id,
            business_name: r.business&.translated_name,
            booking_id: r.booking_id,
            rating: r.rating,
            created_at: r.created_at,
            edited_at: r.edited_at,
            moderation_status: r.moderation_status,
            moderation_notes: r.moderation_notes,
            hidden_at: r.hidden_at,
            flagged_at: r.flagged_at,
            flag_reason: r.flag_reason,
            # Multi-criteria ratings
            cleanliness_rating: r.cleanliness_rating,
            punctuality_rating: r.punctuality_rating,
            professionalism_rating: r.professionalism_rating,
            service_quality_rating: r.service_quality_rating,
            hygiene_rating: r.hygiene_rating,
            ambiance_rating: r.ambiance_rating,
            staff_friendliness_rating: r.staff_friendliness_rating,
            waiting_time_rating: r.waiting_time_rating,
            value_rating: r.value_rating,
            photos: r.photos || [],
          }
        end
      end
    end
  end
end
