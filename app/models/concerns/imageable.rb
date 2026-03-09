# frozen_string_literal: true

module Imageable
  extend ActiveSupport::Concern

  included do
    # Validation for gallery images stored as JSONB
    validate :validate_gallery_images_count, if: -> { respond_to?(:gallery_images) }
  end

  class_methods do
    # Mount CarrierWave uploaders for profile photos
    def has_profile_photos(*fields)
      fields.each do |field|
        mount_uploader field, ImageUploader
      end
    end
  end

  private

  def validate_gallery_images_count
    return unless gallery_images.is_a?(Array)

    return unless gallery_images.size > 10

    errors.add(:gallery_images, "cannot exceed 10 images")
  end
end
