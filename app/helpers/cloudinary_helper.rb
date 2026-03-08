# frozen_string_literal: true

module CloudinaryHelper
  # Generate Cloudinary URL with transformations
  def cloudinary_url(public_id, options = {})
    return nil if public_id.blank?
    
    Cloudinary::Utils.cloudinary_url(public_id, options.merge(secure: true))
  end

  # Generate thumbnail URL (120x120)
  def cloudinary_thumbnail_url(public_id)
    cloudinary_url(public_id, width: 120, height: 120, crop: :fill)
  end

  # Generate standard image URL (800x600)
  def cloudinary_standard_url(public_id)
    cloudinary_url(public_id, width: 800, height: 600, crop: :fill)
  end

  # Generate responsive image URLs
  def cloudinary_responsive_urls(public_id)
    {
      thumbnail: cloudinary_thumbnail_url(public_id),
      standard: cloudinary_standard_url(public_id),
      original: cloudinary_url(public_id)
    }
  end
end
