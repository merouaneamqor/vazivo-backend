# frozen_string_literal: true

class AddLocaleToUsers < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:users, :locale)

    add_column :users, :locale, :string, default: "en", null: false
  end
end
