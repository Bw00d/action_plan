class CreateOrgUnitAssignments < ActiveRecord::Migration[6.0]
  def change
    create_table :org_unit_assignments do |t|
      t.references :org_unit, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true, index: { unique: true }
      t.integer :position

      t.timestamps
    end

    add_index :org_unit_assignments, [:org_unit_id, :position]
  end
end
