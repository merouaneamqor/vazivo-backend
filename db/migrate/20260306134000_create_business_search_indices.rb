class CreateBusinessSearchIndices < ActiveRecord::Migration[7.1]
  def change
    create_table :business_search_indices do |t|
      t.bigint :business_id, null: false
      t.bigint :city_id
      t.bigint :category_id
      t.float :rating, null: false, default: 0.0
      t.integer :reviews_count, null: false, default: 0
      t.decimal :lat, precision: 10, scale: 8
      t.decimal :lng, precision: 11, scale: 8
      t.string :h3_index

      t.timestamps
    end

    add_index :business_search_indices, :business_id, unique: true
    add_index :business_search_indices, [:city_id, :category_id]
    add_index :business_search_indices, :rating
    add_index :business_search_indices, :reviews_count
    add_index :business_search_indices, :h3_index

    add_foreign_key :business_search_indices, :businesses
    add_foreign_key :business_search_indices, :cities
    add_foreign_key :business_search_indices, :categories
  end
end

