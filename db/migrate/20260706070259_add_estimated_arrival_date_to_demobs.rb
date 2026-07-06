class AddEstimatedArrivalDateToDemobs < ActiveRecord::Migration[6.0]
  def change
    add_column :demobs, :estimated_arrival_date, :date unless column_exists?(:demobs, :estimated_arrival_date)
  end
end
