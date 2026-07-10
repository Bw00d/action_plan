class AddCostToIncidents < ActiveRecord::Migration[6.0]
  def change
    # Estimated cost to date, sourced from IRWIN attr_EstimatedCostToDate.
    # Decimal so we can preserve cents if a future data source ever supplies
    # them; IRWIN itself reports whole-dollar amounts.
    add_column :incidents, :cost, :decimal, precision: 14, scale: 2 unless column_exists?(:incidents, :cost)
  end
end
