class AddDropOffPickupToResources < ActiveRecord::Migration[6.0]
  def change
    add_column :resources, :drop_off_pt_time, :string
    add_column :resources, :pick_up_pt_time, :string
  end
end
