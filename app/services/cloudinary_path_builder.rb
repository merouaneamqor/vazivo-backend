# frozen_string_literal: true

# Central helper for Cloudinary folder structure (mandatory spec).
# Use in signed upload endpoint and server-side CloudinaryUploader.upload.
module CloudinaryPathBuilder
  class << self
    def business_cover_folder(business_id)
      "listings/#{business_id}/cover"
    end

    def business_gallery_folder(business_id)
      "listings/#{business_id}/gallery"
    end

    def service_folder(service_id)
      "services/#{service_id}"
    end

    def category_folder(category_id)
      "categories/#{category_id}"
    end

    def city_folder(city_id)
      "cities/#{city_id}"
    end

    def user_avatar_folder(user_id)
      "users/#{user_id}/avatar"
    end

    def review_folder(review_id)
      "reviews/#{review_id}"
    end

    def admin_uploads_folder
      "admin/uploads"
    end

    # Allowed folder prefixes for signed upload validation (user-generated content).
    ALLOWED_FOLDER_PREFIXES = [
      "listings/",
      "businesses/",
      "services/",
      "categories/",
      "cities/",
      "users/",
      "reviews/",
      "admin/",
    ].freeze

    def allowed_folder?(folder)
      return false if folder.blank?

      ALLOWED_FOLDER_PREFIXES.any? { |prefix| folder.to_s.start_with?(prefix) }
    end
  end
end
