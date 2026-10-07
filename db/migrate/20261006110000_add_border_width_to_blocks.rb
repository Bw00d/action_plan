class AddBorderWidthToBlocks < ActiveRecord::Migration[6.0]
  # Border thickness in CSS pixels for kind='border' blocks (the plain
  # rectangle-frame cover element). Stored as a string so "2", "4",
  # etc. can round-trip through the number input without integer-cast
  # surprises. Ignored by every other kind.
  def change
    add_column :blocks, :border_width, :string, default: '2'
  end
end
