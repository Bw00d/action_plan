class AddAgencyAndReleasedAtToRosters < ActiveRecord::Migration[6.0]
  def change
    add_column :rosters, :agency, :string
    add_column :rosters, :released_at, :datetime
    add_index :rosters, :released_at
  end
end
