namespace :incidents do
  desc 'Seed the ICS org chart (Command + 4 sections) for every incident that does not already have one. Idempotent.'
  task backfill_org_charts: :environment do
    total = Incident.count
    seeded = 0

    Incident.find_each do |incident|
      before = incident.org_units.count
      Incidents::SeedOrgChart.call(incident)
      seeded += 1 if incident.org_units.count > before
    end

    puts "Processed #{total} incident(s); seeded org chart for #{seeded}."
  end
end
