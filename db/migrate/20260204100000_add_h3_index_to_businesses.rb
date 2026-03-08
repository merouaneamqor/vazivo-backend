# frozen_string_literal: true

class AddH3IndexToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :h3_index, :string
    add_index :businesses, :h3_index
  end
end
