class CreateDemobs < ActiveRecord::Migration[5.2]
  def change
    create_table :demobs do |t|
      t.integer :resource_id
      t.text :remarks
      t.date :edd
      t.string :edt
      t.string :destination
      t.string :travel_method
      t.boolean :manifest
      t.boolean :manifest_number
      t.boolean :ron
      t.date :actual_release_date
      t.string :actual_release_time
      t.string :eta
      t.string :contact_enroute
      t.boolean :agency_notified
      t.boolean :reassigned
      t.string :new_incident
      t.string :new_incident_number
      t.string :new_order_number
      t.string :prepared_by
      t.string :pb_position
      t.date :date
      t.string :time

      t.timestamps
    end
  end
end
