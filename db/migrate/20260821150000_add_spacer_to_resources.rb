class AddSpacerToResources < ActiveRecord::Migration[6.0]
  def change
    add_column :resources, :spacer, :boolean, default: false, null: false
    add_index :resources, :spacer
  end
end
