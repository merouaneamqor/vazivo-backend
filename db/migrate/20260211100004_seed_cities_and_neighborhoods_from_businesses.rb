# frozen_string_literal: true

class SeedCitiesAndNeighborhoodsFromBusinesses < ActiveRecord::Migration[7.1]
  def up
    # Seed cities from distinct business cities
    distinct_cities = execute(<<-SQL.squish)
      SELECT DISTINCT city FROM businesses
      WHERE city IS NOT NULL AND city != '' AND discarded_at IS NULL
      ORDER BY city
    SQL

    position = 0
    distinct_cities.each do |row|
      name = row["city"]
      slug = name.parameterize
      existing = execute("SELECT id FROM cities WHERE slug = #{ActiveRecord::Base.connection.quote(slug)} LIMIT 1")
      next if existing.count.positive?

      now = Time.current.utc.iso8601
      execute(<<-SQL.squish)
        INSERT INTO cities (name, slug, position, created_at, updated_at)
        VALUES (#{ActiveRecord::Base.connection.quote(name)}, #{ActiveRecord::Base.connection.quote(slug)}, #{position}, '#{now}', '#{now}')
      SQL
      position += 1
    end

    # Seed neighborhoods from distinct business city+neighborhood pairs
    distinct_pairs = execute(<<-SQL.squish)
      SELECT DISTINCT city, neighborhood FROM businesses
      WHERE city IS NOT NULL AND city != '' AND neighborhood IS NOT NULL AND neighborhood != '' AND discarded_at IS NULL
      ORDER BY city, neighborhood
    SQL

    neighborhood_position = Hash.new(0)
    seen = Set.new

    distinct_pairs.each do |row|
      city_name = row["city"]
      neighborhood_name = row["neighborhood"]

      city_row = execute("SELECT id FROM cities WHERE name = #{ActiveRecord::Base.connection.quote(city_name)} LIMIT 1")
      next if city_row.count.zero?

      city_id = city_row.first["id"]
      key = "#{city_id}-#{neighborhood_name}"
      next if seen.include?(key)
      seen.add(key)

      slug = neighborhood_name.parameterize
      existing = execute(<<-SQL.squish)
        SELECT id FROM neighborhoods WHERE city_id = #{city_id} AND slug = #{ActiveRecord::Base.connection.quote(slug)} LIMIT 1
      SQL
      next if existing.count.positive?

      pos = neighborhood_position[city_id]
      now = Time.current.utc.iso8601
      execute(<<-SQL.squish)
        INSERT INTO neighborhoods (city_id, name, slug, position, created_at, updated_at)
        VALUES (#{city_id}, #{ActiveRecord::Base.connection.quote(neighborhood_name)}, #{ActiveRecord::Base.connection.quote(slug)}, #{pos}, '#{now}', '#{now}')
      SQL
      neighborhood_position[city_id] += 1
    end
  end

  def down
    execute("DELETE FROM neighborhoods")
    execute("DELETE FROM cities")
  end
end
