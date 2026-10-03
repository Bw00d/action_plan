class RenamePhone215aEntriesToPhone205aEntries < ActiveRecord::Migration[6.0]
  # Renames the ICS "215A phone list" table to its correct ICS form
  # name, 205A (Communications List). Existing rows and indexes travel
  # with the table.
  def change
    rename_table :phone_215a_entries, :phone_205a_entries
  end
end
