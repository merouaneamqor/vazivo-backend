# frozen_string_literal: true

class CreateClients < ActiveRecord::Migration[7.1]
  def change
    create_table :clients do |t|
      t.references :business, null: false, foreign_key: true
      t.string :name, null: false
      t.string :phone
      t.string :email
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :clients, [:business_id, :email], name: "index_clients_on_business_id_and_email"
  end
end
