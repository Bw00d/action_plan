class AddIncidentIdsToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :incident_ids, :text, array: true, default: []
  end
end
