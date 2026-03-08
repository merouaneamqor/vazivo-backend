# frozen_string_literal: true

module Api
  module V1
    module Admin
      class NeighborhoodsController < BaseController
        # PATCH /api/v1/admin/neighborhoods/:id
        def update
          neighborhood = Neighborhood.find(params[:id])

          if neighborhood.update(permitted_params)
            log_admin_action(:update, "Neighborhood", neighborhood.id, details: { message: "Updated neighborhood ##{neighborhood.id}" }, update_resource: neighborhood)
            render json: {
              neighborhood: {
                id: neighborhood.id,
                name: neighborhood.translated_name,
                slug: neighborhood.translated_slug,
                position: neighborhood.position,
                city_id: neighborhood.city_id,
              },
            }
          else
            render json: { errors: neighborhood.errors.full_messages }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/admin/neighborhoods/:id
        def destroy
          neighborhood = Neighborhood.find(params[:id])
          neighborhood.destroy!
          log_admin_action(:destroy, "Neighborhood", neighborhood.id, details: { message: "Deleted neighborhood ##{neighborhood.id}" })

          render json: { message: "Neighborhood deleted" }
        end

        private

        def permitted_params
          params.permit(
            :name, :position,
            :name_en, :name_fr, :name_ar,
            :slug_en, :slug_fr, :slug_ar
          )
        end
      end
    end
  end
end
