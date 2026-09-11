class EnsureOpsPeriodColumnsOnPlans < ActiveRecord::Migration[6.0]
  # Original migration 20260911000000 didn't land on every environment
  # (same pattern we've hit before — schema drifted out of band). Guard
  # with column_exists? so this runs cleanly whether the columns are
  # missing (adds them) or present (no-op).
  def change
    unless column_exists?(:plans, :ops_period_from)
      add_column :plans, :ops_period_from, :datetime
    end
    unless column_exists?(:plans, :ops_period_to)
      add_column :plans, :ops_period_to, :datetime
    end
  end
end
