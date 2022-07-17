class AddImageToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :image_block, :boolean, default: false
  end
end
