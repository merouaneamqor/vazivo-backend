# frozen_string_literal: true

class BackfillOwnerAsBusinessStaff < ActiveRecord::Migration[7.1]
  def up
    # Ensure every business has its owner in business_staff (idempotent)
    execute <<-SQL
      INSERT INTO business_staffs (business_id, user_id, role, active, created_at, updated_at)
      SELECT b.id, b.user_id, 'owner', true, NOW(), NOW()
      FROM businesses b
      WHERE b.user_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM business_staffs bs
          WHERE bs.business_id = b.id AND bs.user_id = b.user_id
        )
    SQL
  end

  def down
    # No safe reverse: we don't remove owner rows (other code may rely on them)
  end
end
