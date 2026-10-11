# Crew Swap / R&R Refactor — Shift Timeline Model

**Status:** Planning / not started. Pick up when off-incident.
**Codeword:** `shift-refactor`

## Goal

Replace the current "resource has a current operator + scheduled swaps hanging
off the side" model with a clean "sequence of operator shifts" timeline. Fixes:

- LWD being special-cased and brittle during swaps
- Double-counting of days when a swap starts earlier than the previous shift's planned end
- No first-class way to log each leader's actual days worked
- No first-class scheduling for R&R breaks (currently just a boolean flag)

## Data model: shift timeline

Each timeline entry (new `ResourceShift` or repurposed `ResourceEvent`) has:

| Field          | Notes                                                        |
|----------------|--------------------------------------------------------------|
| `kind`         | `:work` or `:rnr`                                            |
| `leader`       | required for `:work`, nil (or inherited for display) for `:rnr` |
| `phone`        | required for `:work`                                         |
| `planned_fwd`  | start date                                                   |
| `planned_days` | length of this entry                                         |
| `actual_fwd`   | set when the entry becomes "current" (SWAP NOW promotes it)  |
| `actual_lwd`   | set when the entry ends (truncated early, or ran full length)|

Entries are ordered by `planned_fwd` ascending. **No overlaps.** Gaps are legal
and represent R&R or any other scheduled break.

## Derived values

- **Effective end of an entry** = `min(planned_fwd + planned_days - 1, next_entry.actual_or_planned_fwd - 1)`.
  Handles early-swap truncation in a single line.
- **Resource.fwd** = first entry's `actual_fwd` (immutable in practice, editable to fix typos).
- **Resource.lwd** = *last work entry's* planned end. R&R after the last work entry doesn't extend LWD.
- **Resource.total_days_worked** = sum of effective days across `:work` entries only. R&R is not "worked."
- **Resource.days_on_incident** = `lwd - fwd + 1` (gross span, includes R&R periods).
- **`resource_present_on?(day)`** = any `:work` entry's effective interval covers `day`.
  An `:rnr` entry explicitly excludes the day. 215 / projections / glide path consume this.
- **Per-leader days** = sum of effective days across that leader's `:work` entries.

## UX

Two buttons on the T-card's compose area, side by side:

- **Schedule Swap** (existing) → leader, phone, FWD, assignment length, notes → creates a `:work` entry.
- **Schedule R&R** (new) → R&R start date, R&R days → creates an `:rnr` entry **and** a follow-on `:work` entry
  with the same leader + their current assignment length (editable). Checkbox "Returning after R&R" defaults on;
  unchecked = no follow-on entry (treated as end-of-assignment the day R&R starts).

**SWAP NOW** semantics simplify: close out the active work entry, promote the next scheduled entry.
If the next entry is `:rnr`, the resource becomes "not present" from that day until R&R ends.

## Example (Joe → R&R → Joe)

- Shift 1: `work`, Joe, 10/1 → planned 14 days (actual_fwd 10/1, actual_lwd 10/14)
- Shift 2: `rnr`, 10/15 → planned 3 days
- Shift 3: `work`, Joe, 10/18 → planned 14 days (actual_lwd 10/31)

Resource.fwd = 10/1. Resource.lwd = 10/31. days_on_incident = 31. total_days_worked = 28.
Joe's work days = 28. Glide path shows 10/15–17 as "not present" (styled distinctly from LWD colors).
Projections for 10/16 don't count this resource.

## Early swap during R&R edge case

Mark covers for Joe during his R&R (schedules a swap for 10/15). That inserts a `:work` entry for Mark.
The `:rnr` entry's effective end gets truncated to 10/14 (Mark's shift starts 10/15).
Same "next entry's `planned_fwd` truncates the current one" rule — nothing special.

## Example (Joe → Mark → Joe, early swap)

Original: Joe scheduled 14 days from 10/1 (LWD 10/14). Joe leaves early 10/11.
Mark covers 10/12–13 (2 days). Joe returns 10/14 for 14 more days.

Entries:
- Shift 1: `work`, Joe, planned 10/1 for 14 days, actual_fwd 10/1, actual_lwd 10/11 (truncated by shift 2)
- Shift 2: `work`, Mark, planned 10/12 for 2 days, actual_fwd 10/12, actual_lwd 10/13
- Shift 3: `work`, Joe, planned 10/14 for 14 days (ends 10/27)

Resource.fwd = 10/1. Resource.lwd = 10/27. total_days_worked = 27 (not 30 — early swap doesn't double-count).

## Migration path

Two realistic options:

1. **Repurpose `ResourceEvent`.** Add kinds `:work` and `:rnr`; backfill current
   `resource.fwd` + `assignment_length` + `leader` as the first `:work` entry;
   existing `scheduled_swap` events become future `:work` entries; existing
   `completed_swap` events become past `:work` entries. The existing
   `resource.r_and_r` boolean becomes a backfilled `:rnr` entry starting today.
   After migration, drop the `r_and_r` column.
2. **New `resource_shifts` table.** Cleaner separation (events-as-log vs shifts-as-state)
   but larger diff. Backfill the same way; event log stays separate for comments.

**Recommended: option 1.** Less code, same semantics.

## Surfaces that will need updating

Non-exhaustive list to size the work before starting:

- `app/models/resource.rb` — `last_work_day`, `latest_scheduled_swap_lwd`, `personnel_by_agency`, R&R scope
- `app/models/resource_event.rb` — add `:work` / `:rnr` kinds, shift semantics
- `app/controllers/resource_events_controller.rb` — SWAP NOW rewrite, new SCHEDULE R&R endpoint
- `app/controllers/boards_controller.rb` — presence filter, personnel rollups
- `app/controllers/ops_controller.rb` — `resource_present_on?`, 215 and projections rebuild
- `app/controllers/resources_controller.rb` — glide path presence
- `app/views/boards/_card.html.erb` — add Schedule R&R button, surface the shift timeline
- `app/views/boards/_activity_feed.html.erb` — render R&R entries alongside work entries
- `app/views/assignments/_ics_204_wf.html.erb` — display rules shouldn't change but needs regression testing
- `app/views/resources/_glide.html.erb` — style R&R cells distinctly
- `app/views/resources/_ics_211.html.erb` — presence-based filters
- `app/views/resources/index.html.erb` — resource tally (R&R vs assigned counts)
- `app/views/planning/*` — IROC reconciler semantics
- `app/views/ops/*` — projections / 215 numbers
- `app/controllers/demobs_controller.rb` — demob flow should close out the current shift
- `app/models/incident.rb` — `tally_resources` scope
- Migrations: add shift fields to `resource_events` (or new `resource_shifts` table), backfill script, drop `r_and_r` column

## Risks

- Big migration. Backfill must be idempotent and must handle every weird historical state (R&R'd + swap scheduled, demobbed mid-swap, etc.).
- Printed PDFs (204, glide, 215) must keep rendering during the deploy window — ideally no visible change in output for resources whose state didn't involve a swap.
- 215's `req × personnel-per-unit` calculation reads `number_personnel` off resources; shift kind doesn't affect that but the "present on day" check will.

## When ready to resume

1. Re-open this file.
2. Create a feature branch (`shift-refactor` or similar).
3. Start with a dry-run migration script that reads current data and prints what the backfill WOULD do (no writes). Review against a prod snapshot.
4. Only then write the real migration and model/controller changes.
