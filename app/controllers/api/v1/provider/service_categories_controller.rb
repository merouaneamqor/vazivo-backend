# frozen_string_literal: true

module Api
  module V1
    module Provider
      class ServiceCategoriesController < BaseController
        before_action :set_business
        before_action :set_category, only: [:show, :update, :destroy, :archive, :unarchive]

        # GET /api/v1/provider/businesses/:business_id/service_categories
        def index
          categories = @business.service_categories.ordered
          categories = categories.active unless params[:include_archived] == "true"

          render json: {
            categories: categories.map { |c| serialize_category(c) },
          }
        end

        # GET /api/v1/provider/businesses/:business_id/service_categories/:id
        def show
          render json: { category: serialize_category(@category) }
        end

        # POST /api/v1/provider/businesses/:business_id/service_categories
        def create
          category = @business.service_categories.build(category_params)

          if category.save
            render json: { category: serialize_category(category) }, status: :created
          else
            render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # PATCH /api/v1/provider/businesses/:business_id/service_categories/:id
        def update
          if @category.update(category_params)
            render json: { category: serialize_category(@category) }
          else
            render json: { errors: @category.errors.full_messages }, status: :unprocessable_entity
          end
        end

        # DELETE /api/v1/provider/businesses/:business_id/service_categories/:id
        def destroy
          @category.destroy
          head :no_content
        end

        # POST /api/v1/provider/businesses/:business_id/service_categories/:id/archive
        def archive
          @category.archive!
          render json: { category: serialize_category(@category) }
        end

        # POST /api/v1/provider/businesses/:business_id/service_categories/:id/unarchive
        def unarchive
          @category.unarchive!
          render json: { category: serialize_category(@category) }
        end

        # POST /api/v1/provider/businesses/:business_id/service_categories/reorder
        def reorder
          order_ids = params[:order] || []
          order_ids.each_with_index do |id, index|
            category = @business.service_categories.find_by(id: id)
            category&.update(position: index)
          end

          head :no_content
        end

        # POST /api/v1/provider/businesses/:business_id/service_categories/:id/generate_description
        def generate_description
          # Simple description generation - can be enhanced with AI later
          description = generate_simple_description(@category.name)
          render json: { description: description }
        end

        private

        def set_business
          @business = current_user.businesses.find(params[:business_id])
        end

        def set_category
          @category = @business.service_categories.find(params[:id])
        end

        def category_params
          params.require(:service_category).permit(:name, :description, :color, :position)
        end

        def serialize_category(category)
          {
            id: category.id,
            name: category.name,
            description: category.description,
            color: category.color,
            position: category.position,
            archived: category.archived?,
            services_count: category.services_count,
            created_at: category.created_at,
            updated_at: category.updated_at,
          }
        end

        def generate_simple_description(name)
          templates = [
            "Professional #{name} services tailored to your needs.",
            "Expert #{name} treatments delivered with care and precision.",
            "High-quality #{name} services for the best results.",
            "Specialized #{name} treatments by experienced professionals.",
          ]
          templates.sample
        end
      end
    end
  end
end
