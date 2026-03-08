class BackfillBusinessCategories < ActiveRecord::Migration[7.1]
  class MigrationBusiness < ApplicationRecord
    self.table_name = "businesses"
  end

  class MigrationCategory < ApplicationRecord
    self.table_name = "categories"
  end

  class MigrationBusinessCategory < ApplicationRecord
    self.table_name = "business_categories"
  end

  def up
    say_with_time "Backfilling business_categories from businesses.categories and businesses.category" do
      MigrationBusiness.find_each do |business|
        labels = []
        if business.respond_to?(:categories)
          raw = business.categories
          if raw.is_a?(Array)
            labels.concat(raw.compact)
          end
        end
        labels << business.category if business.respond_to?(:category) && business.category.present?

        labels.map! { |l| l.to_s.strip }.reject!(&:blank?)
        next if labels.empty?

        category_ids = []

        labels.each do |label|
          downcased = label.downcase
          slug = label.parameterize

          cat = MigrationCategory.where("LOWER(slug) = ?", slug).first ||
                MigrationCategory.where("LOWER(slug_en) = ?", slug).first ||
                MigrationCategory.where("LOWER(name) = ?", downcased).first ||
                MigrationCategory.where("LOWER(name_en) = ?", downcased).first

          category_ids << cat.id if cat
        end

        category_ids.uniq.each do |category_id|
          MigrationBusinessCategory.find_or_create_by!(business_id: business.id, category_id: category_id)
        end
      end
    end
  end

  def down
    # Data-only migration
  end
end

