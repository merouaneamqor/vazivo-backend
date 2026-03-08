class CreateBusinesses < ActiveRecord::Migration[7.1]
  def change
    create_table :businesses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :category, null: false
      t.string :address, null: false
      t.string :city, null: false
      t.decimal :lat, precision: 10, scale: 8
      t.decimal :lng, precision: 11, scale: 8
      t.jsonb :opening_hours, default: {}

      t.timestamps
    end

    add_index :businesses, :category
    add_index :businesses, :city
    add_index :businesses, [:lat, :lng]
  end
end
