namespace :iroc do
  desc "Create a new incident from an IROC dump. Usage: rake 'iroc:create_incident[tmp/Starry.xml]'"
  task :create_incident, [:path] => :environment do |_t, args|
    abort "Usage: rake 'iroc:create_incident[path/to/dump.xml]'" if args[:path].blank?

    result = IrocImporter.new(args[:path]).create_incident!
    puts "Incident #{result.incident.inc_number} — #{result.incident.name} (id #{result.incident.id})"
    puts "  #{result.requests_created} requests created, #{result.requests_updated} updated"
  end

  desc "Import an IROC dump into an existing incident. Usage: rake 'iroc:import[42,tmp/Starry.xml]'"
  task :import, [:incident_id, :path] => :environment do |_t, args|
    abort "Usage: rake 'iroc:import[INCIDENT_ID,path/to/dump.xml]'" if args[:incident_id].blank? || args[:path].blank?

    incident = Incident.find(args[:incident_id])
    result = IrocImporter.new(args[:path]).import_into(incident)
    puts "Incident #{result.incident.inc_number} — #{result.incident.name}"
    puts "  #{result.requests_created} requests created, #{result.requests_updated} updated"
  end
end
