class AddCommoItemIdsToAssignment < ActiveRecord::Migration[5.1]
  def change
    add_column :assignments, :commo_item_ids, :string, array: true
  end
end
