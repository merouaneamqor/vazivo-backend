# frozen_string_literal: true

module Api
  module V1
    module Provider
      class ImagesController < BaseController
        before_action :authenticate_user!
        before_action :set_business

        MAX_IMAGES = 10
        MAX_FILE_SIZE = 5.megabytes
        ALLOWED_CONTENT_TYPES = ["image/png", "image/jpeg", "image/jpg"].freeze

        # POST /api/v1/provider/businesses/:business_id/images
        def create
          uploaded_files = Array(params[:images]).compact
          return render_error("No images provided", :bad_request) if uploaded_files.empty?

          existing_count = (@business.gallery_images || []).size
          max_new = [MAX_IMAGES - existing_count, 0].max

          errors = []
          if uploaded_files.size > max_new
            errors << "Only the first #{max_new} image(s) were uploaded; maximum #{MAX_IMAGES} allowed."
            uploaded_files = uploaded_files.first(max_new)
          end

          results = []
          uploaded_files.each do |file|
            validation_error = validate_image(file)
            if validation_error
              errors << validation_error
              next
            end

            result = upload_to_cloudinary(file)
            if result[:error]
              errors << result[:error]
            else
              @business.add_gallery_image(result[:url], result[:public_id])
              results << result
            end
          end

          @business.reload if results.any?

          if results.any?
            render json: { images: results, errors: errors.presence }, status: :created
          else
            render_error(errors.join(", "), :unprocessable_entity)
          end
        end

        # DELETE /api/v1/provider/businesses/:business_id/images/:public_id
        def destroy
          public_id = params[:id]
          return render_error("Public ID required", :bad_request) if public_id.blank?

          # Delete from Cloudinary
          result = Cloudinary::Uploader.destroy(public_id)
          Rails.logger.info "Cloudinary delete result: #{result.inspect}"

          # Remove from database regardless of Cloudinary result
          # (image might already be deleted from Cloudinary)
          removed = @business.remove_gallery_image(public_id)

          if result["result"] == "ok" || result["result"] == "not found" || removed
            render json: { message: "Image deleted successfully" }
          else
            render_error("Failed to delete image: #{result.inspect}", :unprocessable_entity)
          end
        rescue StandardError => e
          Rails.logger.error "Error deleting image: #{e.message}"
          render_error("Error deleting image: #{e.message}", :internal_server_error)
        end

        private

        def set_business
          @business = current_user.businesses.find(params[:business_id])
        rescue ActiveRecord::RecordNotFound
          render_error("Business not found", :not_found)
        end

        def at_image_limit?
          @business.images.count >= MAX_IMAGES
        end

        def validate_image(file)
          return "Invalid file" unless file.respond_to?(:tempfile) || file.respond_to?(:path)
          return "File too large (max #{MAX_FILE_SIZE / 1.megabyte}MB)" if file.size > MAX_FILE_SIZE
          unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
            return "Invalid file type. Allowed: #{ALLOWED_CONTENT_TYPES.join(', ')}"
          end

          nil
        end

        def upload_to_cloudinary(file)
          upload_result = Cloudinary::Uploader.upload(
            file.tempfile.path,
            folder: "businesses/#{@business.id}",
            public_id: generate_public_id,
            resource_type: "image"
          )

          {
            url: upload_result["secure_url"],
            public_id: upload_result["public_id"],
            width: upload_result["width"],
            height: upload_result["height"],
          }
        rescue StandardError => e
          { error: "Upload failed: #{e.message}" }
        end

        def generate_public_id
          "#{@business.id}_#{SecureRandom.uuid}"
        end

        def render_error(message, status)
          render json: { error: message }, status: status
        end
      end
    end
  end
end
