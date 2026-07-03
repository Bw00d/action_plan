# Deploy Checklist — IROC / Requests / Schedule release

Read this end-to-end before pushing to production. Items marked **PRE-DEPLOY**
should run in prod (or a prod-cloned staging) *before* you promote the release.

## 1. PRE-DEPLOY: check for Resource duplicates

This release adds `validates :order_number, uniqueness: { scope:
[:incident_id, :category] }` on Resource. Existing duplicates are grandfathered
in but will block *edits* to the offending rows.

Run in the prod console:

```ruby
dupes = Resource.group(:incident_id, :category, :order_number).count.select { |_, n| n > 1 }
puts "duplicate combos: #{dupes.size}"
dupes.each { |combo, n| puts "  incident=#{combo[0]} #{combo[1]} order=#{combo[2]}  count=#{n}" }
```

- **0 duplicates** → proceed.
- **A few** → decide row-by-row whether to renumber or delete before deploying.
- **Many** → hold the release and revisit whether the validation should be
  scoped differently.

## 2. PRE-DEPLOY: grep for unguarded `incident.owner` access

`belongs_to :owner` on Incident is now `optional: true`. Any code that assumed
`owner` was always present may raise `NoMethodError`.

```bash
grep -rn "incident\.owner\.\|@incident\.owner\." app/ config/ lib/ | grep -v "&\."
```

Anything printed should either be wrapped in `if` / `&.` or explicitly not care.

## 3. Migrations (safe, additive)

Run in order — the timestamps enforce it:

| # | Migration | What it does |
|---|-----------|--------------|
| 1 | `20260625120000_add_iroc_fields_to_incidents` | Adds IROC header columns + `time_zone` |
| 2 | `20260625120100_create_requests` | New `requests` table |
| 3 | `20260625154754_drop_redundant_iroc_columns_from_incidents` | Drops unused `inc_type`, `inc_number` |
| 4 | `20260701150625_add_return_travel_fields_to_resources` | jetport, return_city, return_state |
| 5 | `20260702093501_create_schedules` | New `schedules` table |

```
bin/rails db:migrate
```

## 4. POST-DEPLOY: backfill schedules for existing incidents

Every existing incident needs its 9-meeting Planning-P schedule seeded.
Without this, the Schedule page renders blank.

Either from the console:

```ruby
Incident.find_each { |i| Schedule.seed_defaults!(i) }
```

Or via the rake task shipped with this release:

```
bin/rails schedules:backfill
```

Both are idempotent — safe to re-run.

## 5. POST-DEPLOY: smoke tests

Hit these URLs and confirm they render without errors for a known incident:

- `/incidents/:id/resources`  — ICS-211 tab, Glide, Demob, Tally
- `/incidents/:id/requests`   — Requests index (should show existing dumps or "no requests" state)
- `/incidents/:id/dump_imports/new` — IROC upload form
- `/incidents/:id/schedules`  — Meeting schedule with the 9 defaults
- `/incidents/:id/board`      — T-Cards board (Unassigned column pinned left, personnel tally per column)

## 6. New behaviors the team should know about

- **IROC dump upload:** icon added next to the new-resource icon on Resources index.
- **Requests page:** new "Requests" nav link; parents nest their subordinates behind a `>` caret; F/C/D status pills tied to matching Resource.
- **Check-in flow:** click a Req # → detail row → Check In button opens a pre-filled resource form.
- **Board columns:** Unassigned pinned left; personnel counts update as cards drag.
- **Glide print:** landscape, colored cells, darker borders, 14-day window.
- **Demob print:** portrait, no page chrome.
- **Meeting schedule:** new "Schedule" nav link; per-meeting checkbox to include in print; landscape → portrait print with title only.

## 7. Things left as-is (pre-existing, not touched)

- `app/views/resources/_form.html.erb` uses `f.text_field` when the block var is `form` — the standalone `/resources/new` page will error. All new code goes through the inline form or the check-in form, both of which work.
- `scope="col table-col"` typos on some `<th>` tags in the same file — HTML tolerates but the class doesn't apply.

## 8. Rollback plan

If a problem surfaces:

- **Migrations 1, 2, 4, 5** are `create_table` / `add_column` — safe to leave in place while rolling back application code.
- **Migration 3** (`drop_redundant_iroc_columns_from_incidents`) drops `inc_type` and `inc_number`. Rolling back the migration recreates them empty; historical values from before the drop are gone. The importer already writes to `incident_type` / `number`, so app code doesn't rely on the dropped columns.
- **App code**: standard rollback to previous release.
- **Backfilled schedules** (from step 4): safe to leave. If you want them gone: `Schedule.delete_all`.
