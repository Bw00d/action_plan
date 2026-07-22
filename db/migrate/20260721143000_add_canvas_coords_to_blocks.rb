class AddCanvasCoordsToBlocks < ActiveRecord::Migration[6.0]
  def change
    # Percentages of the canvas dimensions (0–100). Storing as decimals so
    # the editor and PDF stay in sync regardless of render size.
    add_column :blocks, :x,      :decimal, precision: 6, scale: 3, default: 50.0
    add_column :blocks, :y,      :decimal, precision: 6, scale: 3, default: 10.0
    add_column :blocks, :width,  :decimal, precision: 6, scale: 3, default: 60.0
    add_column :blocks, :height, :decimal, precision: 6, scale: 3, default: 8.0
    add_column :blocks, :kind,   :string,  default: "text"  # "text" or "image"
  end
end
