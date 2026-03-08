# frozen_string_literal: true

class AddOnboardingScoreToBusinesses < ActiveRecord::Migration[7.1]
  def change
    add_column :businesses, :onboarding_score, :integer, default: 0, null: false
    add_index :businesses, :onboarding_score
  end
end
