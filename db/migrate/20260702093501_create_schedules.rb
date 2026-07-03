class CreateSchedules < ActiveRecord::Migration[6.0]
  def change
    create_table :schedules do |t|
      t.references :incident, null: false, foreign_key: true
      t.string  :meeting_name, null: false
      t.string  :time
      t.string  :location
      t.integer :position

      t.timestamps
    end

    add_index :schedules, [:incident_id, :position]
  end
end
