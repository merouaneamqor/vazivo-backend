# frozen_string_literal: true

class MakeBookingIdNullableInReviews < ActiveRecord::Migration[7.1]
  def change
    change_column_null :reviews, :booking_id, true
    change_column_null :reviews, :user_id, true
  end
end
