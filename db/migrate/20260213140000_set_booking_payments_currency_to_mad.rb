# frozen_string_literal: true

class SetBookingPaymentsCurrencyToMad < ActiveRecord::Migration[7.1]
  def up
    change_column_default :booking_payments, :currency, from: "usd", to: "mad"
    execute "UPDATE booking_payments SET currency = 'mad' WHERE currency = 'usd'" if table_exists?(:booking_payments)
  end

  def down
    change_column_default :booking_payments, :currency, from: "mad", to: "usd"
  end
end
