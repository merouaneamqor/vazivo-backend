# frozen_string_literal: true

module Api
  module V1
    module Admin
      class CitiesController < BaseController
        # GET /api/v1/admin/cities
        # Returns nested cities → neighborhoods structure
        def index
          cities = City.ordered.includes(:neighborhoods)

          render json: {
            cities: cities.map { |city| serialize_city(city) },
          }
        end

        # POST /api/v1/admin/cities
        def create
          city = City.new(city_params)

          if city.save
            log_admin_action(:create, "City", city.id, details: { message: "Created city ##{city.id}" })
            render json: { city: serialize_city(city) }, status: :created
          else
            render json: { errors: city.errors.full_messages }, status: :unprocessable_content
          end
        end

        # POST /api/v1/admin/cities/neighborhoods
        # Params: name, city_id
        def create_neighborhood
          city = City.find(params[:city_id])
          neighborhood = city.neighborhoods.build(neighborhood_params)

          if neighborhood.save
            log_admin_action(:create, "Neighborhood", neighborhood.id,
                             details: { message: "Created neighborhood ##{neighborhood.id}" })
            render json: { neighborhood: serialize_neighborhood(neighborhood) }, status: :created
          else
            render json: { errors: neighborhood.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH /api/v1/admin/cities/:id
        def update
          city = City.find(params[:id])

          if city.update(city_params)
            log_admin_action(:update, "City", city.id, details: { message: "Updated city ##{city.id}" },
                                                       update_resource: city)
            render json: { city: serialize_city(city) }
          else
            render json: { errors: city.errors.full_messages }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/admin/cities/:id
        # Cascades to neighborhoods via dependent: :destroy
        def destroy
          city = City.find(params[:id])
          city.destroy!
          log_admin_action(:destroy, "City", city.id, details: { message: "Deleted city ##{city.id}" })

          render json: { message: "City deleted" }
        end

        private

        def city_params
          params.permit(
            :name, :position,
            :name_en, :name_fr, :name_ar,
            :slug_en, :slug_fr, :slug_ar
          )
        end

        def neighborhood_params
          params.permit(
            :name, :position,
            :name_en, :name_fr, :name_ar,
            :slug_en, :slug_fr, :slug_ar
          )
        end

        def serialize_city(c)
          {
            id: c.id,
            name: c.translated_name,
            slug: c.translated_slug,
            position: c.position,
            neighborhoods: c.neighborhoods.ordered.map { |n| serialize_neighborhood(n) },
          }
        end

        def serialize_city_flat(c)
          {
            id: c.id,
            name: c.translated_name,
            slug: c.translated_slug,
            position: c.position,
          }
        end

        def serialize_neighborhood(n)
          {
            id: n.id,
            name: n.translated_name,
            slug: n.translated_slug,
            position: n.position,
            city_id: n.city_id,
          }
        end
      end
    end
  end
end
