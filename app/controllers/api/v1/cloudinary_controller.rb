# frozen_string_literal: true

module Api
  module V1
    class CloudinaryController < ApplicationController
      before_action :authenticate_user!

      # POST /api/v1/cloudinary/signature
      # Returns timestamp, signature, api_key (and optionally folder, public_id) for client-side signed upload.
      def signature
        return render_cloudinary_unavailable unless cloudinary_configured?

        timestamp = Time.current.to_i
        params_to_sign = { timestamp: timestamp }
        params_to_sign[:folder] = params[:folder] if params[:folder].present?
        params_to_sign[:public_id] = params[:public_id] if params[:public_id].present?

        signature = Cloudinary::Utils.api_sign_request(
          params_to_sign,
          Cloudinary.config.api_secret
        )

        payload = {
          timestamp: timestamp,
          signature: signature,
          api_key: Cloudinary.config.api_key,
        }
        payload[:folder] = params[:folder] if params[:folder].present?
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
    end
  end
end
