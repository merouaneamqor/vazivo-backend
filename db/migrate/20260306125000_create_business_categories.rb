class CreateBusinessCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :business_categories do |t|
      t.bigint :business_id, null: false
      t.bigint :category_id, null: false
      t.timestamps
    end

    add_index :business_categories, [:business_id, :category_id], unique: true
    add_foreign_key :business_categories, :businesses
    add_foreign_key :business_categories, :categories
  end
end

