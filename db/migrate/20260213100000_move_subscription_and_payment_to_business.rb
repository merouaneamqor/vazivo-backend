# frozen_string_literal: true

class MoveSubscriptionAndPaymentToBusiness < ActiveRecord::Migration[7.1]
  def up
    # 1. Add premium_expires_at to businesses
    add_column :businesses, :premium_expires_at, :datetime
    add_index :businesses, :premium_expires_at,
              where: "premium_expires_at IS NOT NULL",
              name: "index_businesses_on_premium_expires_at"

    # 2. Subscriptions: add business_id, backfill, then switch
    add_reference :subscriptions, :business, null: true, foreign_key: true
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE subscriptions
          SET business_id = (
            SELECT id FROM businesses
            WHERE businesses.user_id = subscriptions.user_id
            ORDER BY businesses.id ASC
            LIMIT 1
          )
        SQL
      end
    end
    change_column_null :subscriptions, :business_id, false
    remove_foreign_key :subscriptions, :users
    remove_reference :subscriptions, :user, null: false

    # 3. Provider_invoices: add business_id, backfill from subscription then user's first business
    add_reference :provider_invoices, :business, null: true, foreign_key: true
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE provider_invoices
          SET business_id = subscriptions.business_id
          FROM subscriptions
          WHERE provider_invoices.subscription_id = subscriptions.id
        SQL
        execute <<-SQL.squish
          UPDATE provider_invoices
          SET business_id = (
            SELECT id FROM businesses
            WHERE businesses.user_id = provider_invoices.user_id
            ORDER BY businesses.id ASC
            LIMIT 1
          )
          WHERE provider_invoices.business_id IS NULL
        SQL
      end
    end
    change_column_null :provider_invoices, :business_id, false
    remove_foreign_key :provider_invoices, :users
    remove_reference :provider_invoices, :user

    # 4. Backfill business.premium_expires_at from active subscription
    execute <<-SQL.squish
      UPDATE businesses
      SET premium_expires_at = sub.expires_at
      FROM (
        SELECT DISTINCT ON (business_id) business_id, expires_at
        FROM subscriptions
        WHERE status = 'active' AND expires_at > NOW()
        ORDER BY business_id, expires_at DESC
      ) AS sub
      WHERE businesses.id = sub.business_id
    SQL

    # 5. Remove premium_expires_at from users
    remove_index :users, name: "index_users_on_premium_expires_at", if_exists: true
    remove_column :users, :premium_expires_at, :datetime
  end

  def down
    add_column :users, :premium_expires_at, :datetime
    add_index :users, :premium_expires_at, where: "premium_expires_at IS NOT NULL", name: "index_users_on_premium_expires_at"

    add_reference :subscriptions, :user, null: true, foreign_key: true
    execute "UPDATE subscriptions SET user_id = (SELECT user_id FROM businesses WHERE businesses.id = subscriptions.business_id LIMIT 1)"
    change_column_null :subscriptions, :user_id, false
    remove_foreign_key :subscriptions, :businesses
    remove_reference :subscriptions, :business

    add_reference :provider_invoices, :user, null: true, foreign_key: true
    execute "UPDATE provider_invoices SET user_id = (SELECT user_id FROM businesses WHERE businesses.id = provider_invoices.business_id LIMIT 1)"
    change_column_null :provider_invoices, :user_id, false
    remove_foreign_key :provider_invoices, :businesses
    remove_reference :provider_invoices, :business

    execute "UPDATE users SET premium_expires_at = (SELECT MAX(premium_expires_at) FROM businesses WHERE businesses.user_id = users.id) FROM businesses WHERE businesses.user_id = users.id"

    remove_index :businesses, name: "index_businesses_on_premium_expires_at", if_exists: true
    remove_column :businesses, :premium_expires_at, :datetime
  end
end
