class AddResourcesIdsToAssignments < ActiveRecord::Migration[5.1]
  def change
    add_column :assignments, :resource_ids, :string, array: true
  end
end
