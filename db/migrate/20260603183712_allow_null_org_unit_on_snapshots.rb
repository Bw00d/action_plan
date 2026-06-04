class AllowNullOrgUnitOnSnapshots < ActiveRecord::Migration[6.0]
  def change
    change_column_null :plan_assignment_snapshots, :org_unit_id, true
  end
end
