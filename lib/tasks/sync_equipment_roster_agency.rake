namespace :resources do
  desc 'Align EQUIPMENT roster (operator) agencies with their parent resource so the tally matches the 211. ' \
       'Dry run by default; pass APPLY=1 to write. Optional INCIDENT_ID=<id> to limit to one incident.'
  task sync_equipment_roster_agency: :environment do
    apply = ENV['APPLY'] == '1'

    rows = Roster.unscoped
                 .joins(:resource)
                 .where(resources: { category: 'EQUIPMENT', spacer: false })
                 .where.not(resources: { agency: [nil, ''] })
                 .where.not(rosters: { agency: [nil, ''] })   # blank already counts under the parent
                 .where('rosters.agency <> resources.agency')
    rows = rows.where(resources: { incident_id: ENV['INCIDENT_ID'] }) if ENV['INCIDENT_ID'].present?

    count = rows.count
    rows.includes(:resource).find_each do |ros|
      r = ros.resource
      puts "  #{r.full_order_number} #{r.position} #{r.name} — roster ##{ros.id} #{ros.name.inspect}: " \
           "#{ros.agency.inspect} → #{r.agency.inspect}"
      ros.update_columns(agency: r.agency, updated_at: Time.current) if apply
    end

    puts apply ? "Updated #{count} roster row(s)." : "#{count} roster row(s) would change. Re-run with APPLY=1 to write."
  end
end
