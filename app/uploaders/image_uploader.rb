# frozen_string_literal: true

class ImageUploader < CarrierWave::Uploader::Base
  include Cloudinary::CarrierWave

  process eager: true
  process tags: ["profile_photo"]

  version :standard do
    process resize_to_fill: [800, 600, :center]
  end

  version :thumbnail do
    process resize_to_fill: [120, 120, :center]
  end

  def extension_whitelist
    ["jpg", "jpeg", "gif", "png"]
  end

  def public_id
    return @public_id if @public_id

    model.class.name.underscore
    field = mounted_as
    uuid = SecureRandom.uuid
    @public_id = "#{model.id}_#{field}_#{uuid}"
  end

  def default_url
    nil
  end
end
