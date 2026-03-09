# frozen_string_literal: true

module Api
  module V1
    module Public
      class SeoPagesController < BaseController
        # GET /api/v1/public/seo_pages?path=spa/rabat
        def show
          path = params[:path].to_s.strip.sub(%r{\A/+}, "").sub(%r{/+\z}, "")
          seo_page = SeoPage.for_path(path).first

          if seo_page
            render json: {
              path: seo_page.path,
              title: seo_page.title,
              meta_description: seo_page.meta_description,
              seo_text: seo_page.seo_text,
              city: seo_page.city,
              service: seo_page.service,
            }
          else
            render json: {}, status: :not_found
          end
        end
      end
    end
  end
end
