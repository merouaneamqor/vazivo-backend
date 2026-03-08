# frozen_string_literal: true

class BusinessImageUploadJob < ApplicationJob
  queue_as :image_uploads

  sidekiq_options retry: 5

  # Uploads images for one business into Active Storage (logo + images). Idempotent: skips if already has attachments.
  # Uses ProdDataLoadHelpers#upload_business_images_to_cloudinary (uploads to Cloudinary then attaches to AS).
  # Does not raise when no images uploaded (e.g. Cloudinary not configured or all URLs failed)
  # so jobs don't fill the dead queue; logs instead.
  #
  # @param business_id [Integer]
  # @param image_urls [Array<String>]
  def perform(business_id, image_urls)
    business = Business.find_by(id: business_id)
    unless business
      Rails.logger.warn "[BusinessImageUploadJob] Business #{business_id} not found"
      return
    end

    if business.logo.attached? || business.images.attached?
      Rails.logger.debug { "[BusinessImageUploadJob] Business #{business_id} already has images; skipping" }
      return
    end

    image_urls = Array(image_urls).compact_blank
    if image_urls.empty?
      Rails.logger.warn "[BusinessImageUploadJob] Business #{business_id}: no image URLs"
      return
    end

    helper = Object.new.extend(ProdDataLoadHelpers)
    result = helper.upload_business_images_to_cloudinary(business, image_urls)

    if result[:cover_url].present?
      Rails.logger.info "[BusinessImageUploadJob] Business #{business_id}: attached #{result[:gallery_urls].size} images to Active Storage"
      return
    end

    # Don't raise — avoid retries when Cloudinary is missing or all URLs fail (see logs for cause)
    Rails.logger.warn "[BusinessImageUploadJob] Business #{business_id}: no images uploaded (#{image_urls.size} URLs). " \
                      "Check CLOUDINARY_* env on the Sidekiq worker and image URL accessibility."
  end
end
