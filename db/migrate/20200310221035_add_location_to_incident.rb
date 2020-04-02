class AddLocationToIncident < ActiveRecord::Migration[5.1]
  def change
    add_column :incidents, :status, :string
    add_column :incidents, :cause, :string
    add_column :incidents, :fuel_type, :string
    add_column :incidents, :start_date, :date
    add_column :incidents, :containment_date, :date
    add_column :incidents, :control_date, :date
    add_column :incidents, :out_date, :date
    add_column :incidents, :percent_contained, :integer
  end
end
