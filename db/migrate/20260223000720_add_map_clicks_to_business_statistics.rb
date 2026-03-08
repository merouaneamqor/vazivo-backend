class AddMapClicksToBusinessStatistics < ActiveRecord::Migration[7.1]
  def change
    add_column :business_statistics, :google_maps_clicks, :integer, default: 0, null: false
    add_column :business_statistics, :waze_clicks, :integer, default: 0, null: false
  end
end
