class AddOpsPeriodFromToToPlans < ActiveRecord::Migration[6.0]
  # Real datetime fields for the 202 header (mirrors what the 204
  # already has on Assignment). Existing `ops_period` string column
  # stays intact for now — used by the 203 header display until we
  # migrate it too.
  def change
    add_column :plans, :ops_period_from, :datetime
    add_column :plans, :ops_period_to,   :datetime
  end
end
