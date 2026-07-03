namespace :schedules do
  desc "Seed the 9 default Planning-P meetings for every incident that doesn't have them yet. Idempotent."
  task backfill: :environment do
    seeded = 0
    skipped = 0
    Incident.find_each do |inc|
      before = inc.schedules.count
      Schedule.seed_defaults!(inc)
      added = inc.schedules.count - before
      if added.positive?
        seeded += 1
        puts "  incident ##{inc.id} #{inc.name}: added #{added} meetings"
      else
        skipped += 1
      end
    end
    puts ""
    puts "Done. Seeded #{seeded} incident#{'s' unless seeded == 1}, skipped #{skipped} already-complete."
  end
end
