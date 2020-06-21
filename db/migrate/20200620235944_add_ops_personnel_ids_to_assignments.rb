class AddOpsPersonnelIdsToAssignments < ActiveRecord::Migration[5.1]
  def change
    add_column :assignments, :ops_personnel_ids, :string, array: true
  end
end
