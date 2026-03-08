class CreateServices < ActiveRecord::Migration[7.1]
  def change
    create_table :services do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :duration, null: false # in minutes
      t.decimal :price, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :services, :name
  end
end
