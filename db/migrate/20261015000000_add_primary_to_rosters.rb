class AddPrimaryToRosters < ActiveRecord::Migration[6.0]
  def change
    # Marks the subordinate who is the Leader of the parent resource.
    # Only one roster per parent resource can have primary=true; the
    # Roster model enforces this with a before_save that clears siblings.
    add_column :rosters, :primary, :boolean, default: false, null: false
    add_index :rosters, [:resource_id, :primary]
  end
end
