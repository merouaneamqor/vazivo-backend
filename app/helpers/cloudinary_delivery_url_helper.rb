# frozen_string_literal: true

# Builds Cloudinary delivery URLs with the correct multi-component transformation.
# Per Cloudinary rules: resize/crop and effect in separate components, then f_auto and q_auto
# in their own components. Single-component URLs with f_auto,q_auto can fail or not cache.
# See https://cloudinary.com/documentation/cloudinary_transformation_rules
module CloudinaryDeliveryUrlHelper
  CLOUD_NAME = ENV.fetch("CLOUDINARY_CLOUD_NAME", "dqssnduni")

  class << self
    def url(public_id, width: 1000)
      transform = "w_#{width},ar_1:1,c_fill,g_auto/e_art:hokusai/f_auto/q_auto"
      base(transform, public_id)
    end

    def base(transform, public_id)
      pid = public_id.to_s.delete_prefix("/")
      "https://res.cloudinary.com/#{CLOUD_NAME}/image/upload/#{transform}/#{pid}"
    end
  end
end
