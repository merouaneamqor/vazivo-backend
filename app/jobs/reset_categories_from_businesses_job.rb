# frozen_string_literal: true

# Enforces the 5 canonical categories (Salon de Beauté, Barber, Hammam, Massage & Spa, Nail Salon),
# ensures each business.category and business.categories match one of them, and keeps Category table
# in sync so SearchMetadataController#build_categories_data returns correct business_count.
# Run after prod_data:load or any import.
class ResetCategoriesFromBusinessesJob < ApplicationJob
  queue_as :default

  def perform
    Category.ensure_canonical_acts!(ProdDataLoadHelpers::CANONICAL_ACT_TRANSLATIONS)

    # Link every business to the right canonical category by slug
    Business.kept.where.not(category: [nil, ""]).find_each do |business|
      canonical = Category.canonical_name_for_slug(business.category)
      next if canonical.blank?

      updates = { category: canonical, categories: [canonical] }
      next if business.category == canonical && business.categories == [canonical]

      business.update_columns(updates)
    end
  end
end
