class AddDatePreparedToSafetyMessages < ActiveRecord::Migration[5.1]
  def change
    add_column :safety_messages, :date_prepared, :string
    add_column :safety_messages, :time_prepared, :string
    add_column :safety_messages, :ops_period, :string
    drop_table :freqs
  end
end
