# frozen_string_literal: true

class AddProviderStatusToUsers < ActiveRecord::Migration[7.1]
  def up
    add_column :users, :provider_status, :string, default: "not_confirmed"
    add_index :users, :provider_status, where: "role = 'provider'"

    # Confirm existing providers so they retain access
    execute <<-SQL.squish
      UPDATE users SET provider_status = 'confirmed' WHERE role = 'provider'
    SQL
  end

  def down
    remove_index :users, :provider_status, if_exists: true
    remove_column :users, :provider_status
  end
end
