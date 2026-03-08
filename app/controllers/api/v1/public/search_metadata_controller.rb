# frozen_string_literal: true

module Api
  module V1
    module Public
      class SearchMetadataController < BaseController
        # No authentication required for public search metadata

        # GET /api/v1/search_metadata/cities
        def cities
          render json: { cities: build_cities_data }
        end

        # GET /api/v1/search_metadata/categories
        def categories
          render json: { categories: build_categories_data }
        end

        # GET /api/v1/search_metadata/categories_hierarchy
        # Returns full category tree: top-level acts with nested subacts
        def categories_hierarchy
          locale = I18n.locale
          acts = Category.acts.ordered.includes(:children).map do |act|
            {
              id: act.id,
              name: act.translated_name(locale),
              slug: act.translated_slug(locale),
              position: act.position,
              subacts: act.children.ordered.map do |sub|
                {
                  id: sub.id,
                  name: sub.translated_name(locale),
                  slug: sub.translated_slug(locale),
                  position: sub.position,
                }
              end,
            }
          end

          render json: { acts: acts }
        end

        # GET /api/v1/search_metadata/filters
        # Returns all filter options in one endpoint
        def filters
          cities_data = build_cities_data
          categories_data = build_categories_data

          # Get price range from services
          # Use raw SQL to avoid ActiveRecord adding ORDER BY that conflicts with aggregates
          result = ActiveRecord::Base.connection.execute(
            <<~SQL.squish
              SELECT MIN(price) as min_price, MAX(price) as max_price
              FROM services
              INNER JOIN businesses ON businesses.id = services.business_id
              WHERE services.discarded_at IS NULL
                AND businesses.discarded_at IS NULL
            SQL
          )

          row = result.first
          min_price = row ? (row["min_price"] || row[:min_price] || 0) : 0
          max_price = row ? (row["max_price"] || row[:max_price] || 500) : 500

          render json: {
            cities: cities_data,
            categories: categories_data,
            price_range: {
              min: min_price.to_f,
              max: max_price.to_f,
            },
          }
        end

        private

        # Build cities list from City model when available.
        # Falls back to Business.group(:city) if cities table is empty.
        def build_cities_data
          if defined?(City) && City.table_exists? && City.any?
            business_counts = Business.kept
              .group("city")
              .pluck("city", Arel.sql("COUNT(*)"))
              .to_h

            City.ordered.map do |city|
              locale = I18n.locale
              count = business_counts[city.name] || 0
              h = {
                name: city.translated_name(locale),
                slug: city.translated_slug(locale),
                business_count: count,
                image_url: CloudinaryMigrationMapHelper.city_image_url(city.name) || CloudinaryMigrationMapHelper.city_image_url(city.slug),
              }
              h[:lat] = city.lat&.to_f if city.respond_to?(:lat) && city.lat.present?
              h[:lng] = city.lng&.to_f if city.respond_to?(:lng) && city.lng.present?
              h
            end
          else
            Business.kept
              .group("city")
              .order(Arel.sql("COUNT(*) DESC, city ASC"))
              .limit(50)
              .pluck("city", Arel.sql("COUNT(*)"))
              .map do |city_name, count|
                slug = city_name.parameterize
                {
                  name: city_name,
                  slug: slug,
                  business_count: count,
                  image_url: CloudinaryMigrationMapHelper.city_image_url(city_name) || CloudinaryMigrationMapHelper.city_image_url(slug),
                }
              end
          end
        end

        # Build categories list from the Category model (top-level acts only; no subcategories).
        # Falls back to Business.pluck(:category) if the categories table is empty
        # (e.g. migration hasn't run yet).
        def build_categories_data
          locale = I18n.locale
          if Category.acts.any?
            business_counts = Business.kept
              .group("category")
              .pluck("category", Arel.sql("COUNT(*)"))
              .to_h

            Category.acts.ordered.map do |cat|
              count = business_counts[cat.name] || 0
              {
                name: cat.translated_name(locale),
                slug: cat.translated_slug(locale),
                business_count: count,
                parent_id: cat.parent_id,
                icon_url: CloudinaryMigrationMapHelper.category_icon_url(cat.name) || CloudinaryMigrationMapHelper.category_icon_url(cat.slug),
              }
            end
          else
            # Fallback: derive from businesses directly (group by LOWER(category) to avoid duplicate slugs)
            Business.kept
              .where.not(category: [nil, ""])
              .group(Arel.sql("LOWER(category)"))
              .order(Arel.sql("COUNT(*) DESC, LOWER(category) ASC"))
              .pluck(Arel.sql("LOWER(category)"), Arel.sql("COUNT(*)"))
              .map do |category_key, count|
                normalized_slug = category_key.parameterize
                cat = Category.find_by_slug_any_locale(normalized_slug)
                name = Category.translated_name_for(category_key, locale)
                slug = cat ? cat.translated_slug(locale) : normalized_slug
                {
                  name: name,
                  slug: slug,
                  business_count: count,
                  icon_url: CloudinaryMigrationMapHelper.category_icon_url(name) || CloudinaryMigrationMapHelper.category_icon_url(slug),
                }
              end
          end
        end
      end
    end
  end
end
