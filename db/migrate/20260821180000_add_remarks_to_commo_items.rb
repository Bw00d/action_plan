class AddRemarksToCommoItems < ActiveRecord::Migration[6.0]
  def up
    add_column :commo_items, :remarks, :string

    # The 205 UI has been labeling the `mode` column as "Remarks" — any
    # text users typed under that header lives in `mode`. Move it to the
    # newly-named `remarks` column so Mode (204 + new 205 column) starts
    # empty for real-mode values (A/D/M, etc.).
    execute "UPDATE commo_items SET remarks = mode, mode = NULL"
  end

  def down
    execute "UPDATE commo_items SET mode = remarks WHERE mode IS NULL"
    remove_column :commo_items, :remarks
  end
end
