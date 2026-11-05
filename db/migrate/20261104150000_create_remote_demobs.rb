class CreateRemoteDemobs < ActiveRecord::Migration[6.0]
  def change
    create_table :remote_demobs do |t|
      t.references :incident, null: false, foreign_key: true
      # Matched from the typed request number; either may be nil when
      # the number isn't on the incident (yet).
      t.references :resource, foreign_key: true
      t.references :roster, foreign_key: true
      # The ICS-221 the Plans section applied this submission to.
      t.references :demob, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :req_number_raw
      t.string :name
      t.string :phone
      t.string :travel_method
      # Date + "HHMM" strings, the same shape as Demob#edd/edt, so the
      # answer isn't shifted by whichever user's time zone views it.
      t.date   :travel_start_date
      t.string :travel_start_time
      t.string :destination
      t.boolean :ron, null: false, default: false
      t.string :ron_location
      t.date   :arrival_date
      t.string :arrival_time
      t.datetime :submitted_at
      t.datetime :applied_at
      t.timestamps
    end
    add_index :remote_demobs, :status
  end
end
