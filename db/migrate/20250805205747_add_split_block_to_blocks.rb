class AddSplitBlockToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :split_block, :boolean, default: false
  end
end
