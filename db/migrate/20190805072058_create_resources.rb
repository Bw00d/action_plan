class CreateResources < ActiveRecord::Migration[5.1]
  def change
    create_table :resources do |t|
      t.string  :name
      t.string  :leader
      t.integer :number_personnel
      t.string  :position
      t.string  :agency
      t.string  :order_number
      t.date    :lwd
      t.date    :checkin_date
      t.integer :incident_id

      t.timestamps
    end

    add_column  :plans, :incident_id, :integer
  end
end
