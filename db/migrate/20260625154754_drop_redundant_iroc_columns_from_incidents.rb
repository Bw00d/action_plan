class DropRedundantIrocColumnsFromIncidents < ActiveRecord::Migration[6.0]
  def change
    remove_column :incidents, :inc_type,   :string if column_exists?(:incidents, :inc_type)
    remove_column :incidents, :inc_number, :string if column_exists?(:incidents, :inc_number)
  end
end
