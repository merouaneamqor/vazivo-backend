# frozen_string_literal: true

module CloudinaryMigrationMapHelper
  MAP_PATH = Rails.root.join("db/cloudinary_migration_map.json").freeze

  class << self
    def load_map
      return {} unless File.file?(MAP_PATH)

      JSON.parse(File.read(MAP_PATH))
    rescue StandardError
      {}
    end

    def category_icon_url(category_name_or_slug)
      map = load_map
      categories = map["categories"] || {}
      categories[category_name_or_slug] || categories[category_name_or_slug.to_s.parameterize]
    end

    def city_image_url(city_name_or_slug)
      map = load_map
      cities = map["cities"] || {}
      cities[city_name_or_slug] || cities[city_name_or_slug.to_s.parameterize]
    end
  end
end
