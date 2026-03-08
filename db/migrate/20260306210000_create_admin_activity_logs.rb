# frozen_string_literal: true

class CreateAdminActivityLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_activity_logs do |t|
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :resource_type, null: false
      t.string :resource_id
      t.jsonb :details, default: {}
      t.timestamps null: false
    end

    add_index :admin_activity_logs, [:resource_type, :resource_id]
    add_index :admin_activity_logs, :created_at
  end
end
