class RenameBlankToIsBlankInBlocks < ActiveRecord::Migration[6.0]
  def change
    rename_column :blocks, :blank, :is_blank
  end
end
