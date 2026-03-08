# frozen_string_literal: true

class AddFirstLastNameToClients < ActiveRecord::Migration[7.1]
  def change
    add_column :clients, :first_name, :string
    add_column :clients, :last_name, :string

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE clients SET first_name = COALESCE(TRIM(SPLIT_PART(name, ' ', 1)), name), last_name = NULLIF(TRIM(SUBSTRING(name FROM POSITION(' ' IN name) + 1)), '') WHERE name IS NOT NULL;
        SQL
        change_column_null :clients, :first_name, false
      end
    end
  end
end
