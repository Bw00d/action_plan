class AddPromotedResourceToRosters < ActiveRecord::Migration[6.0]
  def change
    add_reference :rosters, :promoted_resource,
                  foreign_key: { to_table: :resources },
                  null: true
  end
end
