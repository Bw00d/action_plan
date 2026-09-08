class AddSiteSafetyFieldsToPlansIfMissing < ActiveRecord::Migration[6.0]
  # Local dev DB already had these columns (added out-of-band); prod
  # Heroku never got them. Guarded so this runs cleanly against either.
  def change
    unless column_exists?(:plans, :site_safety_plan_required)
      add_column :plans, :site_safety_plan_required, :string
    end
    unless column_exists?(:plans, :site_safety_plan_location)
      add_column :plans, :site_safety_plan_location, :text
    end
  end
end
