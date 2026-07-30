namespace :incidents do
  desc 'Seed any missing ICS org chart units on every incident. Command + 4 sections (Operations/Plans/Logistics/Finance), then Safety as a branch under Command and Air as a branch under Operations. Also reparents any Safety/Air that were previously seeded as top-level sections. Idempotent.'
  task backfill_org_charts: :environment do
    total   = Incident.count
    added   = 0
    fixed   = 0
    touched = 0

    Incident.find_each do |incident|
      before = incident.org_units.count

      # Migrate any legacy top-level Safety/Air sections into their new
      # positions before the seeder runs, so find_or_create finds them.
      reparent = ->(name, parent_finder) do
        legacy = incident.org_units.kind_section.find_by(name: name, parent_id: nil)
        return unless legacy
        parent = parent_finder.call
        return unless parent
        legacy.update!(kind: :branch, parent: parent)
        fixed += 1
      end
      reparent.call('Safety', -> { incident.org_units.kind_command.find_by(name: 'Command') })
      reparent.call('Air',    -> { incident.org_units.kind_section.find_by(name: 'Operations') })

      Incidents::SeedOrgChart.call(incident)

      delta = incident.org_units.count - before
      if delta.positive?
        touched += 1
        added   += delta
        puts "  #{incident.number.presence || incident.id}: added #{delta} org unit(s)"
      end
    end

    puts "Processed #{total} incident(s); added #{added} unit(s) across #{touched}; reparented #{fixed} legacy Safety/Air section(s)."
  end
end
