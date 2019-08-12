class AddWeatherToPlans < ActiveRecord::Migration[5.1]
  def change
    add_column :plans, :weather, :text
    add_column :plans, :general_safety, :text
    add_column :plans, :prepared_by, :string
    add_column :plans, :approved_by, :string
    add_column :plans, :org_list, :boolean
    add_column :plans, :assignment_list, :boolean
    add_column :plans, :comm_plan, :boolean
    add_column :plans, :med_plan, :boolean
    add_column :plans, :incident_map, :boolean
    add_column :plans, :travel_plan, :boolean
    add_column :plans, :date_prepare, :date
    add_column :plans, :time_prepared, :string
    add_column :plans, :ops_period, :string
  end
end