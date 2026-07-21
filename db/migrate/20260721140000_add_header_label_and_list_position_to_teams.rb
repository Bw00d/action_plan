class AddHeaderLabelAndListPositionToTeams < ActiveRecord::Migration[6.0]
  def change
    add_column :teams, :header_label,  :string
    add_column :teams, :list_position, :integer
    add_index  :teams, [:plan_id, :staff, :list_position]
  end
end
