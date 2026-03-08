# frozen_string_literal: true

class CloudinaryUploader
  IMAGE_CONTENT_TYPES = [
    "image/jpeg", "image/png", "image/gif", "image/webp", "image/svg+xml", "image/bmp", "image/tiff"
  ].freeze

  class << self
    # Upload a file or URL to Cloudinary (images only).
    # @param file_or_url [File, String, IO] local file path, URL, or IO
    # @param folder [String] e.g. "listings/1/cover", "services/5"
    # @param public_id [String, nil] optional public_id (without folder)
    # @param resource_type [Symbol] :image (default) or :auto
    # @return [Hash] { public_id, secure_url, width, height, bytes } or nil on failure
    def upload(file_or_url, folder:, public_id: nil, resource_type: :image, **options)
      return nil unless cloudinary_configured?

      if file_or_url.respond_to?(:content_type) && file_or_url.content_type.present? && IMAGE_CONTENT_TYPES.exclude?(file_or_url.content_type.to_s.strip.downcase)
        Rails.logger.error "[CloudinaryUploader] upload rejected: non-image MIME #{file_or_url.content_type}"
        raise ArgumentError, "Only image uploads are allowed (got #{file_or_url.content_type})"
      end

      opts = {
        folder: folder,
        use_filename: true,
        unique_filename: true,
        overwrite: true,
        resource_type: resource_type,
      }
      opts[:public_id] = public_id if public_id.present?
      opts.merge!(options)

      result = Cloudinary::Uploader.upload(file_or_url, opts)
      {
        public_id: result["public_id"],
        secure_url: result["secure_url"],
        width: result["width"],
        height: result["height"],
        bytes: result["bytes"],
      }
    rescue ArgumentError
      raise
    rescue StandardError => e
      Rails.logger.error "[CloudinaryUploader] upload failed: #{e.message}"
      nil
    end

    # Delete a resource by public_id (can include folder).
    # @param public_id [String] full public_id
    # @return [Boolean] true if destroyed or not found
    def delete(public_id)
      return false unless cloudinary_configured?

      Cloudinary::Uploader.destroy(public_id)
      true
    rescue Cloudinary::Api::NotFound
      true
    rescue StandardError => e
      Rails.logger.error "[CloudinaryUploader] delete failed: #{e.message}"
      false
    end

    # Rename a resource.
    def rename(from_public_id, to_public_id)
      return nil unless cloudinary_configured?

      Cloudinary::Uploader.rename(from_public_id, to_public_id)
    rescue StandardError => e
      Rails.logger.error "[CloudinaryUploader] rename failed: #{e.message}"
      nil
    end

    # Build a Cloudinary URL with transformations (always f_auto, q_auto; optional width/height/ar).
    # @param public_id [String] full public_id
    # @param transformations [Hash] e.g. { width: 600, crop: "fill", aspect_ratio: "16:9" }
    # @return [String] secure URL
    def url(public_id, transformations = {})
      return nil unless cloudinary_configured? && public_id.present?

      opts = {
        resource_type: :image,
        secure: true,
        quality: "auto",
        fetch_format: "auto",
      }
      opts.merge!(transformations.transform_keys(&:to_sym))
      Cloudinary::Utils.cloudinary_url(public_id, opts)
    end

    # Generate a transformed URL with f_auto,q_auto and optional width/height/crop/aspect_ratio.
    def generate_transformed_url(public_id, options = {})
      opts = { quality: "auto", fetch_format: "auto" }.merge(options)
      url(public_id, opts)
    end

    # Optimize an existing image URL or public_id with transformation params.
    # @param url_or_public_id [String] full Cloudinary URL or public_id
    # @param transformations_hash [Hash] e.g. { width: 600, crop: "fill" }
    # @return [String] transformed secure URL
    def optimize(url_or_public_id, transformations_hash = {})
      return nil if url_or_public_id.blank?

      public_id = if url_or_public_id.to_s.include?("res.cloudinary.com")
                    # Extract public_id from URL: .../upload/v123/ path + filename without extension
                    path = url_or_public_id.to_s.split("/upload/").last
                    return url_or_public_id if path.blank?

                    parts = path.sub(%r{\Av\d+/}, "").split("/") # strip version prefix
                    name = parts.pop
                    name = name.sub(/\.[^.]+\z/, "") if name # strip extension
                    parts.push(name).join("/")
                  else
                    url_or_public_id
                  end
      generate_transformed_url(public_id, transformations_hash)
    end

    private

    def cloudinary_configured?
      defined?(Cloudinary) &&
        Cloudinary.config.api_key.present? &&
        Cloudinary.config.api_secret.present?
    end
  end
end
