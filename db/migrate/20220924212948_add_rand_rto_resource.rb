class AddRandRtoResource < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :r_and_r, :boolean, default: false
  end
end
