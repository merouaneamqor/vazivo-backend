# frozen_string_literal: true

class AddDeviseColumnsToUsers < ActiveRecord::Migration[7.1]
  def change
    # Rename to Devise default column names (same bcrypt content / reset flow)
    rename_column :users, :password_digest, :encrypted_password
    rename_column :users, :password_reset_token, :reset_password_token
    rename_column :users, :password_reset_sent_at, :reset_password_sent_at
  end
end
