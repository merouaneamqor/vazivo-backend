# frozen_string_literal: true

class AddCarrierwaveFieldsToUsersAndServices < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :avatar, :string
    add_column :services, :image, :string
  end
end
