# frozen_string_literal: true

module Api
  module V1
    module Provider
      class UploadsController < BaseController
        before_action :authenticate_user!

        # POST /api/v1/uploads/presign
        # Generate a presigned URL for direct uploads to MinIO/S3
        def presign
          blob = ActiveStorage::Blob.create_before_direct_upload!(
            filename: params[:filename],
            byte_size: params[:byte_size],
            checksum: params[:checksum],
            content_type: params[:content_type]
          )

          render json: {
            direct_upload: {
              url: blob.service_url_for_direct_upload,
              headers: blob.service_headers_for_direct_upload,
            },
            blob_signed_id: blob.signed_id,
          }
        end

        # POST /api/v1/uploads/confirm
        # Confirm that a direct upload has completed
        def confirm
          blob = ActiveStorage::Blob.find_signed!(params[:signed_id])

          render json: {
            blob_id: blob.id,
            signed_id: blob.signed_id,
            url: storage_url_for(blob),
          }
        end

        # POST /api/v1/uploads/cloudinary-sign
        # Returns signature, api_key, timestamp, folder for client-side signed upload to Cloudinary.
        # Params: folder (required), optional public_id, resource_type (default image).
        def cloudinary_sign
          return render_cloudinary_unavailable unless cloudinary_configured?

          resource_type = params[:resource_type].presence || "image"
          unless resource_type == "image"
            return render json: { error: "Only image uploads are allowed" }, status: :unprocessable_content
          end

          folder = params[:folder].to_s.strip
          unless CloudinaryPathBuilder.allowed_folder?(folder)
            return render json: { error: "Invalid or disallowed folder" }, status: :unprocessable_content
          end

          timestamp = Time.current.to_i
          params_to_sign = { timestamp: timestamp, folder: folder }
          params_to_sign[:public_id] = params[:public_id] if params[:public_id].present?

          signature = Cloudinary::Utils.api_sign_request(
            params_to_sign,
            Cloudinary.config.api_secret
          )

          payload = {
            signature: signature,
            api_key: Cloudinary.config.api_key,
            timestamp: timestamp,
            folder: folder,
          }
          payload[:public_id] = params[:public_id] if params[:public_id].present?
          payload[:cloud_name] = Cloudinary.config.cloud_name if Cloudinary.config.cloud_name.present?

          render json: payload
        end

        private

        def cloudinary_configured?
          defined?(Cloudinary) &&
            Cloudinary.config.api_key.present? &&
            Cloudinary.config.api_secret.present?
        end

        def render_cloudinary_unavailable
          render json: { error: "Cloudinary is not configured" }, status: :service_unavailable
        end

        def storage_url_for(blob)
          case Rails.application.config.active_storage.service
          when :minio
            endpoint = ENV.fetch("MINIO_PUBLIC_ENDPOINT", "http://localhost:9000")
            bucket = ENV.fetch("MINIO_BUCKET", "vazivo-development")
            "#{endpoint}/#{bucket}/#{blob.key}"
          when :cloudinary
            folder = ENV.fetch("CLOUDINARY_FOLDER", "glow").presence
            public_id = folder ? "#{folder}/#{blob.key}" : blob.key
            CloudinaryDeliveryUrlHelper.url(public_id)
          else
            Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true)
          end
        end
      end
    end
  end
end
