class AddImagePositionToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :image_position_x, :string
  end
end
