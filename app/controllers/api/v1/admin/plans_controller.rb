# frozen_string_literal: true

module Api
  module V1
    module Admin
      class PlansController < BaseController
        # GET /api/v1/admin/plans
        def index
          plans = Plan.ordered

          render json: {
            plans: plans.map { |p| serialize_plan(p) },
          }
        end

        # POST /api/v1/admin/plans
        def create
          plan = Plan.new(plan_params)

          if plan.save
            log_admin_action(:create, "Plan", plan.id, details: { message: "Created plan ##{plan.id}" })
            render json: { plan: serialize_plan(plan) }, status: :created
          else
            render json: { errors: plan.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH /api/v1/admin/plans/:id
        def update
          plan = Plan.find(params[:id])

          if plan.update(plan_params)
            log_admin_action(:update, "Plan", plan.id, details: { message: "Updated plan ##{plan.id}" },
                                                       update_resource: plan)
            render json: { plan: serialize_plan(plan) }
          else
            render json: { errors: plan.errors.full_messages }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/admin/plans/:id
        def destroy
          plan = Plan.find(params[:id])
          plan.destroy!
          log_admin_action(:destroy, "Plan", plan.id, details: { message: "Deleted plan ##{plan.id}" })
          render json: { message: "Plan deleted" }
        end

        private

        def plan_params
          params.permit(
            :name, :identifier, :duration_months, :suggested_price, :currency, :active, :position,
            :name_en, :name_fr, :name_ar
          )
        end

        def serialize_plan(p)
          {
            id: p.id,
            name: p.translated_name,
            identifier: p.identifier,
            duration_months: p.duration_months,
            suggested_price: p.suggested_price&.to_f,
            currency: p.currency,
            active: p.active,
            position: p.position,
            created_at: p.created_at&.iso8601,
            updated_at: p.updated_at&.iso8601,
          }
        end
      end
    end
  end
end
