class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews, if_not_exists: true do |t|
      # index: false — we add a unique index on booking_id below
      t.references :booking, null: false, foreign_key: true, index: false
      t.references :business, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :comment

      t.timestamps
    end

    add_index :reviews, :rating, if_not_exists: true
    add_index :reviews, :booking_id, unique: true, if_not_exists: true
  end
end
