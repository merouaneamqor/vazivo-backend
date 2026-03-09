# frozen_string_literal: true

class AddIndexSubscriptionsPlanId < ActiveRecord::Migration[7.1]
  def change
    add_index :subscriptions, :plan_id
  end
end
