class AddTimeZoneToUsers < ActiveRecord::Migration[6.0]
  def change
    # Nullable — nil means the user hasn't set/detected a TZ yet, and
    # the app falls back to the global config.time_zone (Alaska).
    add_column :users, :time_zone, :string
  end
end
