# frozen_string_literal: true

module Api
  module V1
    module Admin
      class CategoriesController < BaseController
        # GET /api/v1/admin/categories
        # Returns nested acts → subacts structure
        def index
          authorize Category
          acts = Category.acts.ordered.includes(:children)

          render json: {
            acts: acts.map { |act| serialize_act(act) },
          }
        end

        # POST /api/v1/admin/categories
        # Params: name, parent_id (optional)
        def create
          category = Category.new(category_params)
          authorize category

          if category.save
            log_admin_action(:create, "Category", category.id, details: { message: "Created category ##{category.id}" })
            render json: { category: serialize_category(category) }, status: :created
          else
            render json: { errors: category.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH /api/v1/admin/categories/:id
        # Params: name, position
        def update
          category = Category.find(params[:id])
          authorize category

          if category.update(category_params)
            log_admin_action(:update, "Category", category.id,
                             details: { message: "Updated category ##{category.id}" }, update_resource: category)
            render json: { category: serialize_category(category) }
          else
            render json: { errors: category.errors.full_messages }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/admin/categories/:id
        # Cascade-deletes children (subacts) via dependent: :destroy
        def destroy
          category = Category.find(params[:id])
          authorize category
          category.destroy!
          log_admin_action(:destroy, "Category", category.id, details: { message: "Deleted category ##{category.id}" })

          render json: { message: "Category deleted" }
        end

        private

        def category_params
          params.permit(:name, :name_en, :name_fr, :name_ar, :slug_en, :slug_fr, :slug_ar, :parent_id, :position)
        end

        def serialize_act(act)
          {
            id: act.id,
            name: act.name,
            name_en: act.name_en,
            name_fr: act.name_fr,
            name_ar: act.name_ar,
            slug: act.slug,
            slug_en: act.slug_en,
            slug_fr: act.slug_fr,
            slug_ar: act.slug_ar,
            translated_name: act.translated_name,
            position: act.position,
            subacts: act.children.ordered.map { |child| serialize_category(child) },
          }
        end

        def serialize_category(cat)
          {
            id: cat.id,
            name: cat.name,
            name_en: cat.name_en,
            name_fr: cat.name_fr,
            name_ar: cat.name_ar,
            slug: cat.slug,
            slug_en: cat.slug_en,
            slug_fr: cat.slug_fr,
            slug_ar: cat.slug_ar,
            translated_name: cat.translated_name,
            position: cat.position,
            parent_id: cat.parent_id,
          }
        end
      end
    end
  end
end
