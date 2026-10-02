class CreatePhone215aEntries < ActiveRecord::Migration[6.0]
  def change
    create_table :phone_215a_entries do |t|
      t.references :incident, null: false, foreign_key: true, index: true
      t.string :name
      t.string :position
      t.string :phone_number
      t.string :section
      # Lets users reorder entries within a section later without
      # breaking the display grouping. Not surfaced in the UI yet;
      # ordering falls back to name when sort_order ties.
      t.integer :sort_order, default: 0, null: false
      t.timestamps
    end

    add_index :phone_215a_entries, [:incident_id, :section]
  end
end
