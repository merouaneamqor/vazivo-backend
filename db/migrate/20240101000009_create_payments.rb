class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :booking, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :stripe_payment_intent_id
      t.string :stripe_customer_id
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: "usd"
      t.string :status, default: "pending"
      t.jsonb :metadata, default: {}
      t.datetime :paid_at
      t.datetime :refunded_at

      t.timestamps
    end

    add_index :payments, :stripe_payment_intent_id, unique: true
    add_index :payments, :status
  end
end
