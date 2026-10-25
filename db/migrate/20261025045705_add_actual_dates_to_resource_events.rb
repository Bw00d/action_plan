# Shift refactor — step 1 of N: add the two columns that distinguish
# planned vs actual dates on a ResourceEvent used as a shift timeline
# entry.
#
# After this migration + the model enum add of :work and :rnr, a shift
# entry stores:
#   fwd         — planned start (reused column; was already the start
#                 date for scheduled/completed swap events)
#   lwd         — planned end   (reused column; was the end date for
#                 completed_swap events; for new :work entries it's
#                 the planned_fwd + planned_days - 1 date)
#   actual_fwd  — date the entry became "current" (SWAP NOW promotes
#                 the next scheduled entry and sets this)
#   actual_lwd  — date the entry was closed out (ran its full length
#                 or was truncated by an early swap / demob)
#
# Nothing is renamed and nothing is dropped. Legacy scheduled_swap /
# completed_swap rows remain readable until the backfill rewrites
# their kind to :work.
class AddActualDatesToResourceEvents < ActiveRecord::Migration[6.0]
  def change
    add_column :resource_events, :actual_fwd, :date
    add_column :resource_events, :actual_lwd, :date
  end
end
