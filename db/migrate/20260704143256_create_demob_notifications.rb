class CreateDemobNotifications < ActiveRecord::Migration[6.0]
  def change
    create_table :demob_notifications do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.references :demob,    null: true,  foreign_key: true

      # Snapshot of the demob data at the moment the resource was released,
      # so later edits to the Demob record don't silently rewrite what was
      # (or is about to be) sent to dispatch.
      t.string  :request_number
      t.string  :unit_id
      t.string  :name
      t.date    :actual_release_date
      t.string  :actual_release_time
      t.string  :return_travel_method
      t.string  :demob_city_state
      t.boolean :ron, default: false
      t.string  :ron_location
      t.date    :est_arrival_date
      t.string  :est_arrival_time
      t.text    :remarks

      # Transmission tracking
      t.boolean  :transmitted, default: false, null: false
      t.datetime :transmitted_at

      t.timestamps
    end

    add_index :demob_notifications, :transmitted
    add_index :demob_notifications, [:incident_id, :transmitted]
  end
end
