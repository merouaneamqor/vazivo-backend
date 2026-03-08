class CreateSeoPages < ActiveRecord::Migration[7.1]
  def change
    create_table :seo_pages do |t|
      t.string :path, null: false
      t.string :title
      t.text :meta_description
      t.text :seo_text
      t.string :city
      t.string :service
      t.references :business, null: true, foreign_key: true
      t.timestamps
    end

    add_index :seo_pages, :path, unique: true
    add_index :seo_pages, :city
    add_index :seo_pages, :service
  end
end
