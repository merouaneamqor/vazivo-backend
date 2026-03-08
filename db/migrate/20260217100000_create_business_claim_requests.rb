# frozen_string_literal: true

class CreateBusinessClaimRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :business_claim_requests do |t|
      t.references :business, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :email, null: false
      t.string :name, null: false
      t.text :message
      t.string :status, default: "pending", null: false

      t.timestamps
    end

    add_index :business_claim_requests, :status
    add_index :business_claim_requests, [:business_id, :status]
  end
end
