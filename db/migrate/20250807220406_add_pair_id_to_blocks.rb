class AddPairIdToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :pair_id, :string
  end
end
