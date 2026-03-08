# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "active"
      t.string :plan_id, null: false, default: "premium_monthly"
      t.string :paid_via, null: false, default: "stripe"
      t.datetime :started_at, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :subscriptions, :status
    add_index :subscriptions, :expires_at
  end
end
