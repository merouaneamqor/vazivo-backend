# frozen_string_literal: true

class SeedCategoriesFromBusinesses < ActiveRecord::Migration[7.1]
  def up
    # Seed a Category record for each distinct business category (as an act, no parent)
    distinct_categories = execute("SELECT DISTINCT category FROM businesses WHERE category IS NOT NULL AND category != '' AND discarded_at IS NULL ORDER BY category")
    position = 0
    distinct_categories.each do |row|
      name = row["category"]
      slug = name.parameterize
      # Avoid duplicates if migration is re-run
      existing = execute("SELECT id FROM categories WHERE slug = #{ActiveRecord::Base.connection.quote(slug)} LIMIT 1")
      if existing.count.zero?
        now = Time.current.utc.iso8601
        execute <<-SQL.squish
          INSERT INTO categories (name, slug, parent_id, position, created_at, updated_at)
          VALUES (#{ActiveRecord::Base.connection.quote(name)}, #{ActiveRecord::Base.connection.quote(slug)}, NULL, #{position}, '#{now}', '#{now}')
        SQL
        position += 1
      end
    end
  end

  def down
    # Remove only top-level categories (acts) seeded from businesses
    execute("DELETE FROM categories WHERE parent_id IS NULL")
  end
end
