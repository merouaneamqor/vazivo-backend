# frozen_string_literal: true

class AddVerificationAndGeoToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :verification_status, :string, default: "unverified", null: false
    add_column :businesses, :geo_validated, :boolean, default: false, null: false
    add_index :businesses, :verification_status
  end
end
