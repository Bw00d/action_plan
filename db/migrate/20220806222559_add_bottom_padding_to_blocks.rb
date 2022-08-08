class AddBottomPaddingToBlocks < ActiveRecord::Migration[5.2]
  def change
    add_column :blocks, :bottom_padding, :string, default: '0'
    add_column :blocks, :blank, :boolean, default: false
  end
end
