# frozen_string_literal: true

class BackfillBusinessesH3Index < ActiveRecord::Migration[7.1]
  def up
    return unless table_exists?(:businesses) && column_exists?(:businesses, :h3_index)

    Business.reset_column_information
    Business.kept.find_each do |business|
      next unless business.lat.present? && business.lng.present?

      business.update_column(
        :h3_index,
        H3.from_geo_coordinates(
          [business.lat.to_f, business.lng.to_f],
          Business::H3_RESOLUTION
        ).to_s(16)
      )
    end
  end

  def down
    # No-op: backfill is one-way; we don't clear h3_index on rollback
  end
end
