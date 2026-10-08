class AddNotesToResources < ActiveRecord::Migration[6.0]
  # Free-form notes about the CURRENT operator — surfaced on the T-card
  # modal's amber Notes block. Populated automatically when a swap is
  # executed (SWAP NOW) with the incoming operator's notes, and the
  # previous value gets appended to the outgoing completed_swap event
  # body so no history is lost.
  def change
    add_column :resources, :notes, :text
  end
end
