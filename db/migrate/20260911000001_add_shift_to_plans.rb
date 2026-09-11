class AddShiftToPlans < ActiveRecord::Migration[6.0]
  # DAY / NIGHT toggle shown next to "2. Operational Period:" on the
  # 202 header. New plans default to DAY at the DB layer; existing
  # rows get backfilled so best_in_place has a value to render (nil
  # would show as an empty click target with no visible label).
  def up
    add_column :plans, :shift, :string, default: 'DAY'
    execute "UPDATE plans SET shift = 'DAY' WHERE shift IS NULL"
  end

  def down
    remove_column :plans, :shift
  end
end
