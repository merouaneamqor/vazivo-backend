# frozen_string_literal: true

# Build Cloudinary URLs for OG/Twitter card images with optional text overlay.
# Use on listing pages and categories.
module CloudinaryOgImageBuilder
  class << self
    CLOUD_NAME = ENV.fetch("CLOUDINARY_CLOUD_NAME", "dqssnduni")

    # Generate OG image URL for a business listing.
    # @param business [Business] or hash with :name, :city, :logo_url, :average_rating
    # @param options [Hash] width, height, crop
    # @return [String] full Cloudinary URL for OG image
    def listing_url(business, options = {})
      cover = business.respond_to?(:logo_url) ? business.logo_url : business[:logo_url]
      return default_og_url(options) if cover.blank?

      if cover.to_s.include?("res.cloudinary.com")
        public_id = extract_public_id(cover)
        opts = { width: 1200, height: 630, crop: "fill" }.merge(options)
        transform = "w_#{opts[:width]},h_#{opts[:height]},c_#{opts[:crop]},g_auto/e_art:hokusai/f_auto/q_auto"
        "https://res.cloudinary.com/#{CLOUD_NAME}/image/upload/#{transform}/#{public_id}"
      else
        default_og_url(options)
      end
    end

    # Default OG image when no cover is available (e.g. placeholder or logo).
    def default_og_url(options = {})
      w = options[:width] || 1200
      h = options[:height] || 630
      transform = "w_#{w},h_#{h},c_fill,g_auto/e_art:hokusai/f_auto/q_auto"
      "https://res.cloudinary.com/#{CLOUD_NAME}/image/upload/#{transform}/sample"
    end

    private

    def extract_public_id(url)
      path = url.to_s.split("/upload/").last
      return "sample" if path.blank?

      parts = path.sub(%r{\Av\d+/}, "").split("/")
      name = parts.pop
      name = name.sub(/\.[^.]+\z/, "") if name
      parts.push(name).join("/")
    end
  end
end
