# frozen_string_literal: true

module Api
  module V1
    module Admin
      class SeoPagesController < BaseController
        # GET /api/v1/admin/seo_pages
        def index
          pages = SeoPage.order(:path)

          render json: {
            seo_pages: pages.map { |p| serialize_seo_page(p) },
          }
        end

        # GET /api/v1/admin/seo_pages/:id
        def show
          page = SeoPage.find(params[:id])
          render json: { seo_page: serialize_seo_page(page) }
        end

        # POST /api/v1/admin/seo_pages
        def create
          page = SeoPage.new(seo_page_params)

          if page.save
            log_admin_action(:create, "SeoPage", page.id, details: { message: "Created SEO page ##{page.id}" })
            render json: { seo_page: serialize_seo_page(page) }, status: :created
          else
            render json: { errors: page.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH /api/v1/admin/seo_pages/:id
        def update
          page = SeoPage.find(params[:id])

          if page.update(seo_page_params)
            log_admin_action(:update, "SeoPage", page.id, details: { message: "Updated SEO page ##{page.id}" }, update_resource: page)
            render json: { seo_page: serialize_seo_page(page) }
          else
            render json: { errors: page.errors.full_messages }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/admin/seo_pages/:id
        def destroy
          page = SeoPage.find(params[:id])
          page.destroy!
          log_admin_action(:destroy, "SeoPage", page.id, details: { message: "Deleted SEO page ##{page.id}" })
          render json: { message: "SEO page deleted" }
        end

        private

        def seo_page_params
          params.permit(:path, :title, :meta_description, :seo_text, :city, :service, :business_id)
        end

        def serialize_seo_page(p)
          {
            id: p.id,
            path: p.path,
            title: p.title,
            meta_description: p.meta_description,
            seo_text: p.seo_text,
            city: p.city,
            service: p.service,
            business_id: p.business_id,
            created_at: p.created_at&.iso8601,
            updated_at: p.updated_at&.iso8601,
          }
        end
      end
    end
  end
end
