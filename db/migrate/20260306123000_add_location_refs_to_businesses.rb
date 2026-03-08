class AddLocationRefsToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_reference :businesses, :city, foreign_key: true, null: true
    add_reference :businesses, :neighborhood, foreign_key: true, null: true
  end
end

