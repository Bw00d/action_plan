class AddOpsPeriodToAssignments < ActiveRecord::Migration[5.1]
  def change
    add_column :assignments, :ops_period, :string
  end
end
