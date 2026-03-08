# frozen_string_literal: true

class AddOauthToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :oauth_provider, :string
    add_column :users, :oauth_uid, :string
    add_index :users, %i[oauth_provider oauth_uid], unique: true, where: "oauth_provider IS NOT NULL"
  end
end
