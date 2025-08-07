class AddImageDimensionsToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :image_width, :string
    add_column :blocks, :image_height, :string
  end
end
