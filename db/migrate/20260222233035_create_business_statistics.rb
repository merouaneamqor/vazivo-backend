class CreateBusinessStatistics < ActiveRecord::Migration[7.1]
  def change
    create_table :business_statistics do |t|
      t.references :business, null: false, foreign_key: true
      t.integer :phone_clicks, default: 0, null: false
      t.integer :profile_views, default: 0, null: false
      t.integer :booking_clicks, default: 0, null: false
      t.timestamps
    end

    add_index :business_statistics, :business_id, unique: true unless index_exists?(:business_statistics, :business_id)
  end
end
