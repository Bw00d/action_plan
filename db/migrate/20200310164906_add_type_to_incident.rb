class AddTypeToIncident < ActiveRecord::Migration[5.1]
  def change
    add_column :incidents, :incident_type, :string
    add_column :incidents, :complexity, :string
  end
end
