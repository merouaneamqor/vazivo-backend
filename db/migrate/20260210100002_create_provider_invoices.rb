# frozen_string_literal: true

class CreateProviderInvoices < ActiveRecord::Migration[7.1]
  def change
    create_table :provider_invoices do |t|
      t.string :invoice_id, null: false
      t.references :user, null: false, foreign_key: true
      t.references :subscription, null: true, foreign_key: true
      t.decimal :total, precision: 10, scale: 2, null: false
      t.string :currency, null: false, default: "mad"
      t.string :status, null: false, default: "pending"
      t.string :payment_method
      t.datetime :paid_at
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    add_index :provider_invoices, :invoice_id, unique: true
    add_index :provider_invoices, :status
    add_index :provider_invoices, :paid_at
  end
end
