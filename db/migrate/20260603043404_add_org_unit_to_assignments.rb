class AddOrgUnitToAssignments < ActiveRecord::Migration[6.0]
  def change
    add_reference :assignments, :org_unit, foreign_key: true, null: true
  end
end
