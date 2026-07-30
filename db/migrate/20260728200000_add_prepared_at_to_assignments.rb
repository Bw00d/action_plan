class AddPreparedAtToAssignments < ActiveRecord::Migration[6.0]
  def change
    add_column :assignments, :prepared_date, :date
    add_column :assignments, :prepared_time, :string
  end
end
