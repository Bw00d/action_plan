class CreateCheckins < ActiveRecord::Migration[5.2]
  def change
    create_table :checkins do |t|
      t.integer :incident_id
      t.string :agency
      t.string :category
      t.string :position
      t.float :order_number
      t.date :checkin_date
      t.string :leader
      t.string :contact_info
      t.string :home_unit
      t.string :other_quals
      t.boolean :other_incident, default: false
      t.string :other_incident_name
      t.date :first_day_worked
      t.string :name
      t.integer :number_personnel
      t.string :name
      t.integer :resource_id

      t.timestamps
    end
  end
end
