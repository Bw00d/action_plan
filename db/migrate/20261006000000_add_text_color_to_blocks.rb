class AddTextColorToBlocks < ActiveRecord::Migration[6.0]
  # Per-block text color for cover text/notes blocks. Stored as a CSS
  # color string ("#000", "#c62828", "rgb(…)") so the client can send
  # whatever the palette offers without a lookup table. Null means
  # "inherit" — matches the historical default of black.
  def change
    add_column :blocks, :text_color, :string
  end
end
