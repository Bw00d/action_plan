namespace :iroc do
  desc "Create a new incident from an IROC dump. Usage: rake 'iroc:create_incident[path/to/dump.xml,Alaska]'"
  task :create_incident, [:path, :time_zone] => :environment do |_t, args|
    abort "Usage: rake 'iroc:create_incident[path/to/dump.xml,TIME_ZONE]'" if args[:path].blank?

    result = IrocImporter.new(args[:path], time_zone: args[:time_zone]).create_incident!
    puts "Incident #{result.incident.number} — #{result.incident.name} (id #{result.incident.id})"
    puts "  time zone: #{result.incident.time_zone || '(none)'}"
    puts "  #{result.requests_created} requests created, #{result.requests_skipped} already present"
  end

  desc "Import an IROC dump into an existing incident. Usage: rake 'iroc:import[42,path/to/dump.xml,Alaska]'"
  task :import, [:incident_id, :path, :time_zone] => :environment do |_t, args|
    abort "Usage: rake 'iroc:import[INCIDENT_ID,path/to/dump.xml,TIME_ZONE]'" if args[:incident_id].blank? || args[:path].blank?

    incident = Incident.find(args[:incident_id])
    result = IrocImporter.new(args[:path], time_zone: args[:time_zone]).import_into(incident)
    puts "Incident #{result.incident.number} — #{result.incident.name}"
    puts "  #{result.requests_created} requests created, #{result.requests_skipped} already present"
  end
end
