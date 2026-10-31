class AddResourceNotesToAssignments < ActiveRecord::Migration[6.0]
  def change
    # Free-text lines typed into the blank rows of the 204's Resource
    # Designator table, in row order. Blank entries hold a row's place.
    add_column :assignments, :resource_notes, :string, array: true, default: [], null: false
  end
end
