# frozen_string_literal: true

class RenamePaymentsToBookingPayments < ActiveRecord::Migration[7.1]
  def change
    rename_table :payments, :booking_payments
  end
end
