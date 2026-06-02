class CreatePlanAssignmentSnapshots < ActiveRecord::Migration[6.0]
  def change
    create_table :plan_assignment_snapshots do |t|
      t.references :plan, null: false, foreign_key: true
      t.references :org_unit, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.integer :position
      t.string :designator_at_publish

      t.timestamps
    end

    add_index :plan_assignment_snapshots,
              [:plan_id, :org_unit_id, :position],
              name: 'index_pa_snapshots_on_plan_unit_position'
  end
end
