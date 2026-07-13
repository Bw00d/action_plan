class ChangeResourcesOrderNumberToString < ActiveRecord::Migration[6.0]
  # Widened so subordinate resources like strike-team engines (e.g. "209.3")
  # or crew members within them ("209.3.1") can be stored. Existing integer
  # values convert cleanly via CAST — Postgres handles it in place.
  def up
    change_column :resources, :order_number, :string
  end

  def down
    # Down migration only works if every current order_number is a plain
    # integer string. Fractional or non-numeric values will fail — they'd
    # need cleanup before rolling back.
    change_column :resources, :order_number,
                  'integer USING CAST(NULLIF(order_number, \'\') AS integer)'
  end
end
