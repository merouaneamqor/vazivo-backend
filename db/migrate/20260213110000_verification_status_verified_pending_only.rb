# frozen_string_literal: true

class VerificationStatusVerifiedPendingOnly < ActiveRecord::Migration[7.1]
  def up
    # Backfill: treat "unverified" as "pending"
    execute <<-SQL.squish
      UPDATE businesses SET verification_status = 'pending' WHERE verification_status = 'unverified'
    SQL
    change_column_default :businesses, :verification_status, from: "unverified", to: "pending"
  end

  def down
    change_column_default :businesses, :verification_status, from: "pending", to: "unverified"
  end
end
