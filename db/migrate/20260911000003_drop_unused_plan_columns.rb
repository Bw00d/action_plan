class DropUnusedPlanColumns < ActiveRecord::Migration[6.0]
  # Cleanup — these columns exist on some plans DBs from earlier work
  # but nothing in the current codebase reads or writes them. Guarded
  # with column_exists? so this runs cleanly whether they're present
  # (drops them) or missing (no-op).
  #
  # Mapping of what replaced each column, for future reference:
  #   date_from, date_to, time_from, time_to → ops_period_from / ops_period_to (datetime)
  #   objectives_content                     → objectives_text
  #   prepared_by_title                      → prepared_by_position
  #   ic_date_time                           → date_prepare + time_prepared (unchanged)
  #   iap_page                               → hardcoded "IAP Page" in the sheet template

  UNUSED = %i[
    date_from
    date_to
    time_from
    time_to
    objectives_content
    prepared_by_title
    ic_date_time
    iap_page
  ].freeze

  def up
    UNUSED.each do |col|
      remove_column :plans, col if column_exists?(:plans, col)
    end
  end

  # No down — we've thrown away the data. If you need to restore any of
  # these columns, add them back explicitly in a new migration.
  def down
    raise ActiveRecord::IrreversibleMigration,
          "DropUnusedPlanColumns dropped orphan columns; recreate manually if needed."
  end
end
