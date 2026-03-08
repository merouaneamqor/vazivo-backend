class AddFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :last_login_at, :datetime
    add_column :users, :password_reset_token, :string
    add_column :users, :password_reset_sent_at, :datetime
    add_column :users, :discarded_at, :datetime

    add_index :users, :discarded_at
    add_index :users, :password_reset_token, unique: true
  end
end
