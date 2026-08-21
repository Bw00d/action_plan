class CreateOps215Lines < ActiveRecord::Migration[6.0]
  def change
    create_table :ops_215_lines do |t|
      t.references :incident, foreign_key: true, null: false
      t.references :org_unit, foreign_key: true, null: false
      t.date :day, null: false
      t.string :position, null: false
      t.integer :req, default: 0, null: false
      t.timestamps
    end

    add_index :ops_215_lines,
              [:incident_id, :org_unit_id, :day, :position],
              unique: true,
              name: 'idx_ops_215_lines_key'
  end
end
