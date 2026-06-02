class CreateOrgUnits < ActiveRecord::Migration[6.0]
  def change
    create_table :org_units do |t|
      t.references :incident, null: false, foreign_key: true, index: true
      t.references :parent, foreign_key: { to_table: :org_units }
      t.integer :kind, null: false
      t.string :name, null: false
      t.string :designator
      t.integer :position

      t.timestamps
    end

    add_index :org_units, [:parent_id, :position]
    add_index :org_units, [:incident_id, :kind]
  end
end
