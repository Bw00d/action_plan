class AddOpsPersonnelSlotsToAssignments < ActiveRecord::Migration[6.0]
  def change
    add_reference :assignments, :operations_chief,
                  foreign_key: { to_table: :teams }, null: true
    add_reference :assignments, :division_group_supervisor,
                  foreign_key: { to_table: :teams }, null: true
    add_reference :assignments, :branch_director,
                  foreign_key: { to_table: :teams }, null: true
    add_reference :assignments, :air_attack_supervisor,
                  foreign_key: { to_table: :teams }, null: true
  end
end
