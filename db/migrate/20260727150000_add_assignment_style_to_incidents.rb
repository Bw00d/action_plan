class AddAssignmentStyleToIncidents < ActiveRecord::Migration[6.0]
  def change
    add_column :incidents, :assignment_style, :string, default: "ics_204_wf", null: false
  end
end
