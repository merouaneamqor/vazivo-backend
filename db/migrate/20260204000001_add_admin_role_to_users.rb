# frozen_string_literal: true

class AddAdminRoleToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :admin_role, :string
    add_index :users, :admin_role, where: "admin_role IS NOT NULL"
  end
end
