class AddSoftDeleteToBusinessesAndServices < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :discarded_at, :datetime
    add_column :businesses, :phone, :string
    add_column :businesses, :email, :string
    add_column :businesses, :website, :string

    add_column :services, :discarded_at, :datetime

    add_index :businesses, :discarded_at
    add_index :services, :discarded_at
  end
end
