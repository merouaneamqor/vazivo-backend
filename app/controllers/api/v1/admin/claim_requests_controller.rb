# frozen_string_literal: true

module Api
  module V1
    module Admin
      class ClaimRequestsController < BaseController
        def index
          scope = BusinessClaimRequest.includes(:business, :user).order(created_at: :desc)
          scope = scope.where(status: params[:status]) if params[:status].present?
          scope = scope.where(business_id: params[:business_id]) if params[:business_id].present?
          @pagy, requests = pagy(scope, items: params[:per_page] || 20)

          items = requests.map { |r| claim_request_item(r) }
          render json: { claim_requests: items, meta: pagination_meta }
        end

        def show
          req = BusinessClaimRequest.includes(:business, :user).find(params[:id])
          render json: {
            claim_request: claim_request_item(req).merge(message: req.message),
            business: req.business ? BusinessSerializer.new(req.business).as_json : nil,
            user: req.user ? UserSerializer.new(req.user).as_json : nil,
          }
        end

        def approve
          req = BusinessClaimRequest.find(params[:id])
          unless req.status == "pending"
            return render json: { error: "Request is not pending" }, status: :unprocessable_content
          end

          req.update!(status: "approved")
          # Assign business to the claimer if user_id present
          if req.user_id.present?
            req.business.update!(user_id: req.user_id)
            req.business.business_staff.find_or_create_by!(user_id: req.user_id) do |bs|
              bs.role = "owner"
              bs.active = true
            end
          end
          log_admin_action(:approve, "ClaimRequest", req.id, details: { message: "Approved claim request ##{req.id}" })
          render json: { claim_request: claim_request_item(req.reload), message: "Claim approved" }
        end

        def reject
          req = BusinessClaimRequest.find(params[:id])
          unless req.status == "pending"
            return render json: { error: "Request is not pending" }, status: :unprocessable_content
          end

          req.update!(status: "rejected")
          log_admin_action(:reject, "ClaimRequest", req.id, details: { message: "Rejected claim request ##{req.id}" })
          render json: { claim_request: claim_request_item(req.reload), message: "Claim rejected" }
        end

        private

        def claim_request_item(r)
          {
            id: r.id,
            business_id: r.business_id,
            business_name: r.business&.translated_name,
            business_slug: r.business&.translated_slug,
            user_id: r.user_id,
            user_name: r.user&.name,
            email: r.email,
            name: r.name,
            status: r.status,
            created_at: r.created_at,
            updated_at: r.updated_at,
          }
        end
      end
    end
  end
end
