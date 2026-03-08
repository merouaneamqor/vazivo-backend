# frozen_string_literal: true

class AddPremiumExpiresAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :premium_expires_at, :datetime, null: true
    add_index :users, :premium_expires_at, where: "premium_expires_at IS NOT NULL"
  end
end
