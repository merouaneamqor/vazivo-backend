# frozen_string_literal: true

class AddCountryToBusinesses < ActiveRecord::Migration[7.1]
  def up
    add_column :businesses, :country, :string, default: "Morocco"
    execute <<-SQL.squish
      UPDATE businesses SET country = 'Morocco' WHERE country IS NULL
    SQL
  end

  def down
    remove_column :businesses, :country
  end
end
