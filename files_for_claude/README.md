# IROC Dump Import — Context for Claude Code

This folder contains a starter implementation for importing **IROC / e-ISuite**
incident dumps into a Rails incident action plan app, plus a real sample dump to
work against. Please review, wire it into the app, and build out the remaining
pieces described under **Next steps**.

## What this feature does

The app manages wildfire incident action plans. Dispatch produces IROC dumps (a
Cognos `dataSet` XML export) listing an incident and every resource ordered/
assigned to it. We want two import paths:

1. **Create an incident from a dump** — read the dump's header and populate a new
   `Incident`, then import all of its request lines.
2. **Add to an existing incident** — as more resources get assigned, later dumps
   are imported into an incident that already exists, adding the new request
   lines (and refreshing any that changed).

Each request line is stored as a `Request` record. `Request` data will later be
used to create `Resource` records (not built yet — see Next steps).

## The data source

`Starry.xml` is a real sample dump. It's a Cognos `dataSet` document
(namespace `http://www.ibm.com/xmlns/prod/cognos/dataSet/201006`) containing two
tables, each a `<dataTable>` with an `<id>` and a set of `<row>` elements.

- **IncidentHeader** — exactly 1 row, the incident itself (10 fields).
- **IncidentRequests** — 188 rows in this sample, one per resource order line
  (25 fields).

Important characteristics of the data:

- **IDs are 32-char hex GUIDs, no dashes.** `IncID` links the two tables.
  `ReqID` is unique per request line (verified: 188/188 unique in the sample).
  `ResID` identifies the assigned resource.
- **Booleans arrive as the strings `"Yes"` / `"No"`.**
- **Timestamps are `YYYY-MM-DDThh:mm:ss.fffffffff` with no timezone.** These
  incidents are Alaska — parse through `Time.zone` and set
  `config.time_zone = "Alaska"`.
- **Empty fields appear as self-closing tags** (e.g. `<MiddleName/>`) and should
  map to `nil`.
- **IncidentRequests is a mixed resource table.** Personnel rows (catalog
  `Overhead` or `Crew`) carry name and employment fields; aircraft, equipment,
  and supply rows leave those null. `req_catalog_name` is the discriminator.

### IncidentHeader → Incident fields

| Dump field | Column | Type |
|---|---|---|
| IncID | iroc_inc_id | string (GUID, unique key) |
| IncNumber | inc_number | string |
| IncName | name | string |
| IncType | inc_type | string |
| IncState | state | string |
| InitialDate | initial_date | datetime |
| IncAgencyAbbrev | agency_abbrev | string |
| IncDispOrgUnitCode | disp_org_unit_code | string |
| MergedIncFlag | merged_inc_flag | boolean |
| PreviousIncNumber | previous_inc_number | string (nullable) |

### IncidentRequests → Request fields

GUIDs: `ReqID` → iroc_req_id (unique), `ResID` → iroc_res_id, plus
`incident_id` FK. Remaining: root_req_flag (bool), req_number_prefix,
req_number, req_catalog_name (Aircraft/Crew/Equipment/Overhead/Supply),
req_category_name, res_name, assignment_name, res_prov_agency_abbrev,
res_prov_unit_code, filled_catalog_item_code, filled_catalog_item_name,
employment_class (personnel only), jet_port, mob_etd (datetime),
vendor_owned_flag (bool), vendor_name, contract_type, contract_number,
last_name / first_name / middle_name (personnel only).

## Files in this folder

- `iroc_importer.rb` → **app/services/iroc_importer.rb** — the importer service,
  the core of both workflows.
- `20260625120000_add_iroc_fields_to_incidents.rb` → **db/migrate/** — adds the
  header fields to the existing `incidents` table.
- `20260625120100_create_requests.rb` → **db/migrate/** — creates the `requests`
  table.
- `request.rb` → **app/models/request.rb** — the new model.
- `incident_additions.rb` — **snippet**, not a drop-in. Merge its lines
  (`has_many :requests`, validation, scopes) into the existing
  `app/models/incident.rb`.
- `iroc.rake` → **lib/tasks/iroc.rake** — convenience rake tasks.
- `Starry.xml` — the sample dump for testing.

## How it works (design decisions to preserve)

- **Idempotent.** Incidents are matched on `iroc_inc_id`, requests on
  `iroc_req_id`. Re-importing the same dump updates existing rows in place and
  inserts only genuinely new request lines — no duplicates.
- **Upsert on re-import.** When a `ReqID` already exists, its row is updated
  (e.g. a request gets filled, an ETD shifts). The marked line in
  `import_requests!` shows how to switch to strictly insert-only if that's
  preferred later.
- **Mismatch guard.** Mode 2 raises `IrocImporter::DumpMismatch` if the dump's
  `IncID` doesn't match the target incident, so a dump can't be poured into the
  wrong incident. A global unique index on `iroc_req_id` is a second safety net.
- **Flexible input.** `IrocImporter.new(source)` accepts a file path, a raw XML
  string, or an IO (e.g. an uploaded file). It strips the Cognos namespace so
  plain xpath works.

Usage:

```ruby
IrocImporter.new("tmp/Starry.xml").create_incident!              # mode 1
IrocImporter.new(uploaded_file).import_into(Incident.find(id))   # mode 2
```

```bash
rails iroc:create_incident[tmp/Starry.xml]
rails iroc:import[42,tmp/Starry.xml]
```

## Setup

1. Move each file to the path noted above; merge `incident_additions.rb` into the
   real `Incident` model.
2. Set the migrations' `ActiveRecord::Migration[7.1]` to this app's Rails version.
3. Set `config.time_zone = "Alaska"` if not already.
4. `rails db:migrate`
5. Smoke-test: `rails iroc:create_incident[<path to Starry.xml>]` — expect 1
   incident and 188 requests created (114 of them personnel).

## Things to reconcile (don't assume)

- The `incidents` migration guards each `add_column` with `column_exists?`, so
  it's safe to run, but **check it against the real `incidents` schema.** If a
  column like `name` or `state` already exists under that or a different name,
  reconcile so the importer writes to the intended column.
- The importer calls `incident.save!`. If the existing `Incident` model has
  required validations beyond these fields, mode 1 may fail — adjust the
  importer or model accordingly.

## Next steps (to build)

1. **Request → Resource creation.** Use `Request` records to create `Resource`
   records. `req_catalog_name` is the branch point: `Overhead`/`Crew` are people
   (use the `personnel` scope; name fields populated), the rest are equipment/
   aircraft/supply (`non_personnel` scope). Decide how Resources relate to
   Requests (one-to-one? dedupe people across incidents by `ResID`?).
2. **Importer specs.** Cover both modes, idempotency (re-import = no dupes),
   the upsert path (changed row updates), and the mismatch guard, using
   `Starry.xml` as a fixture.
3. **Upload UI / controller.** A way to upload a dump and pick "create new
   incident" vs "import into incident X," surfacing the result counts and any
   `DumpMismatch`.
