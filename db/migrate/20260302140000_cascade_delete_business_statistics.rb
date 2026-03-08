class CascadeDeleteBusinessStatistics < ActiveRecord::Migration[7.1]
  def change
    # Replace the plain FK with one that cascades on deletion.
    # Without CASCADE, deleting a Business that has a BusinessStatistic row raises
    # PG::ForeignKeyViolation even though Business has `has_one :statistic, dependent: :destroy`,
    # because Discard's default_scope (or timing) can prevent Rails from loading the
    # association before the DELETE hits PostgreSQL.
    remove_foreign_key :business_statistics, :businesses
    add_foreign_key :business_statistics, :businesses, on_delete: :cascade
  end
end
