class BackfillBusinessCityAndNeighborhood < ActiveRecord::Migration[7.1]
  class MigrationBusiness < ApplicationRecord
    self.table_name = "businesses"
  end

  class MigrationCity < ApplicationRecord
    self.table_name = "cities"
  end

  class MigrationNeighborhood < ApplicationRecord
    self.table_name = "neighborhoods"
  end

  def up
    say_with_time "Backfilling businesses.city_id from businesses.city" do
      MigrationBusiness.where(city_id: nil).find_each do |business|
        next if business.city.blank?

        name = business.city.to_s.strip
        downcased = name.downcase
        slug = name.parameterize

        city = MigrationCity.where("LOWER(name) = ?", downcased).first ||
               MigrationCity.where("LOWER(slug) = ?", slug.downcase).first ||
               MigrationCity.where("LOWER(name_en) = ?", downcased).first

        next unless city

        business.update_columns(city_id: city.id)
      end
    end

    say_with_time "Backfilling businesses.neighborhood_id from businesses.neighborhood" do
      MigrationBusiness.where.not(city_id: nil).where(neighborhood_id: nil).find_each do |business|
        next if business.neighborhood.blank?

        name = business.neighborhood.to_s.strip
        downcased = name.downcase
        slug = name.parameterize

        neighborhoods = MigrationNeighborhood.where(city_id: business.city_id)
        neighborhood = neighborhoods.where("LOWER(name) = ?", downcased).first ||
                       neighborhoods.where("LOWER(slug) = ?", slug.downcase).first ||
                       neighborhoods.where("LOWER(name_en) = ?", downcased).first

        next unless neighborhood

        business.update_columns(neighborhood_id: neighborhood.id)
      end
    end
  end

  def down
    # Data-only migration
  end
end

