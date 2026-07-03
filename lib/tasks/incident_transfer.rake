# Rake tasks to transfer a single Incident's full state between environments.
#
# Export (on the source, e.g. development):
#   bin/rails 'data:export_incident[10,tmp/starry.json]'
#
# Import (on the target, e.g. staging or production):
#   bin/rails 'data:import_incident[tmp/starry.json]'
#
# The import creates NEW rows on the target (source ids are ignored except as
# lookup keys for FK remapping). Idempotency: refuses to import if an incident
# with the same iroc_inc_id already exists on the target — delete that first
# with Incident.find_by(iroc_inc_id: '…').destroy if you want to re-run.

namespace :data do
  # This app's config/initializers/time_formats.rb overrides Date#to_s and
  # Time#to_s to "%m/%d/%y" (two-digit year), which JSON serialization
  # inherits. If we let that through, "2026-07-01" becomes "07/01/26" in the
  # dump and parses back as year 26. Normalize with explicit strftime so the
  # export is round-trip safe regardless of app-level date format overrides.
  def iso_attrs(record)
    record.attributes.transform_values do |v|
      case v
      when Date     then v.strftime('%Y-%m-%d')
      when Time     then v.utc.iso8601
      when DateTime then v.to_time.utc.iso8601
      else v
      end
    end
  end

  desc "Dump one incident + its requests/resources/demobs/schedules/org_units to JSON. Usage: data:export_incident[INCIDENT_ID,OUT_PATH]"
  task :export_incident, [:id, :out] => :environment do |_t, args|
    abort "Usage: data:export_incident[INCIDENT_ID,OUT_PATH]" if args[:id].blank? || args[:out].blank?

    incident = Incident.find(args[:id])
    resource_ids = incident.resources.pluck(:id)
    org_unit_ids = incident.org_units.pluck(:id)

    payload = {
      "meta"      => { "exported_at" => Time.zone.now.iso8601, "source_incident_id" => incident.id },
      "incident"  => iso_attrs(incident),
      "requests"  => incident.requests.map { |r| iso_attrs(r) },
      "resources" => incident.resources.map { |r| iso_attrs(r) },
      "demobs"    => Demob.where(resource_id: resource_ids).map { |r| iso_attrs(r) },
      "schedules" => incident.schedules.map { |r| iso_attrs(r) },
      "org_units" => incident.org_units.map { |r| iso_attrs(r) },
      "org_unit_assignments" => OrgUnitAssignment.where(org_unit_id: org_unit_ids).map { |r| iso_attrs(r) }
    }

    File.write(args[:out], JSON.pretty_generate(payload))

    puts "Exported incident ##{incident.id} — #{incident.name}"
    puts "  → #{args[:out]}"
    puts "  requests:              #{payload['requests'].size}"
    puts "  resources:             #{payload['resources'].size}"
    puts "  demobs:                #{payload['demobs'].size}"
    puts "  schedules:             #{payload['schedules'].size}"
    puts "  org_units:             #{payload['org_units'].size}"
    puts "  org_unit_assignments:  #{payload['org_unit_assignments'].size}"
  end

  desc "Load an incident JSON dump onto this environment. Usage: data:import_incident[IN_PATH]"
  task :import_incident, [:in] => :environment do |_t, args|
    abort "Usage: data:import_incident[IN_PATH]" if args[:in].blank?
    abort "File not found: #{args[:in]}" unless File.exist?(args[:in])

    payload = JSON.parse(File.read(args[:in]))
    inc_attrs = payload.fetch("incident")

    if inc_attrs["iroc_inc_id"].present?
      if Incident.exists?(iroc_inc_id: inc_attrs["iroc_inc_id"])
        abort "Refusing to import: an incident with iroc_inc_id=#{inc_attrs['iroc_inc_id']} already exists on the target. Delete it first if you really want to re-import."
      end
    end

    resource_id_map  = {}   # source_resource_id  → new_resource_id
    org_unit_id_map  = {}   # source_org_unit_id  → new_org_unit_id

    ActiveRecord::Base.transaction do
      # Suppress create-time callbacks that would auto-seed duplicates.
      Incident.skip_callback(:create, :after, :seed_default_schedule)
      Resource.skip_callback(:create, :after, :create_demob)

      # ---- Incident ----
      new_incident = Incident.new(inc_attrs.except("id", "created_at", "updated_at"))
      new_incident.save!(validate: false)
      new_incident.update_columns(
        created_at: inc_attrs["created_at"] || Time.zone.now,
        updated_at: inc_attrs["updated_at"] || Time.zone.now
      )
      puts "Created incident ##{new_incident.id} — #{new_incident.name}"

      # ---- Requests ----
      payload["requests"].each do |r|
        Request.new(r.except("id").merge("incident_id" => new_incident.id)).save!(validate: false)
      end
      puts "  requests:              #{payload['requests'].size}"

      # ---- Resources ----
      payload["resources"].each do |r|
        src_id = r["id"]
        new_r  = Resource.new(r.except("id").merge("incident_id" => new_incident.id))
        new_r.save!(validate: false)
        new_r.update_columns(created_at: r["created_at"], updated_at: r["updated_at"]) if r["created_at"]
        resource_id_map[src_id] = new_r.id
      end
      puts "  resources:             #{payload['resources'].size}"

      # ---- Demobs (each ties to a resource) ----
      payload["demobs"].each do |d|
        new_resource_id = resource_id_map[d["resource_id"]]
        next unless new_resource_id
        Demob.new(d.except("id").merge("resource_id" => new_resource_id)).save!(validate: false)
      end
      puts "  demobs:                #{payload['demobs'].size}"

      # ---- Schedules ----
      payload["schedules"].each do |s|
        Schedule.new(s.except("id").merge("incident_id" => new_incident.id)).save!(validate: false)
      end
      puts "  schedules:             #{payload['schedules'].size}"

      # ---- OrgUnits (parent_id is self-referential — two-pass) ----
      # Pass 1: create with parent_id set to nil; remember source parent id.
      pending_parents = {}   # new_org_unit_id → source_parent_id
      payload["org_units"].each do |u|
        src_id = u["id"]
        src_parent = u["parent_id"]
        new_u = OrgUnit.new(
          u.except("id", "parent_id")
            .merge("incident_id" => new_incident.id, "parent_id" => nil)
        )
        new_u.save!(validate: false)
        new_u.update_columns(created_at: u["created_at"], updated_at: u["updated_at"]) if u["created_at"]
        org_unit_id_map[src_id] = new_u.id
        pending_parents[new_u.id] = src_parent if src_parent
      end
      # Pass 2: patch parent_id now that we have the full mapping.
      pending_parents.each do |new_id, src_parent|
        new_parent = org_unit_id_map[src_parent]
        OrgUnit.where(id: new_id).update_all(parent_id: new_parent) if new_parent
      end
      puts "  org_units:             #{payload['org_units'].size}"

      # ---- OrgUnitAssignments ----
      payload["org_unit_assignments"].each do |a|
        new_ou_id = org_unit_id_map[a["org_unit_id"]]
        new_r_id  = resource_id_map[a["resource_id"]]
        next unless new_ou_id && new_r_id
        OrgUnitAssignment.new(
          a.except("id")
            .merge("org_unit_id" => new_ou_id, "resource_id" => new_r_id)
        ).save!(validate: false)
      end
      puts "  org_unit_assignments:  #{payload['org_unit_assignments'].size}"

      # Restore callbacks (transaction-scoped restore in case anything else runs
      # in the same process).
      Incident.set_callback(:create, :after, :seed_default_schedule)
      Resource.set_callback(:create, :after, :create_demob)
    end

    puts ""
    puts "Import complete. Verify at /incidents/#{Incident.last.id}/…"
  end
end
