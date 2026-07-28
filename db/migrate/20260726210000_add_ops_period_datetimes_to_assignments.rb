class AddOpsPeriodDatetimesToAssignments < ActiveRecord::Migration[6.0]
  def change
    add_column :assignments, :ops_period_from, :datetime
    add_column :assignments, :ops_period_to, :datetime
  end
end
