class AddProtectionToIncidents < ActiveRecord::Migration[5.1]
  def change
    add_column :incidents, :location, :string
    add_column :incidents, :ownership, :string
    add_column :incidents, :protection, :string
    add_column :incidents, :latitude, :string
    add_column :incidents, :longitude, :string
    add_column :incidents, :ic, :string
    add_column :incidents, :fire_behavior, :string
  end
end
