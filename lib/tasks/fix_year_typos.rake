namespace :resources do
  desc 'Fix resources whose fwd or checkin_date has a two-digit year (e.g. 0026 instead of 2026). Adds 2000 to any date whose year is below 1900. Idempotent — safe to re-run.'
  task fix_year_typos: :environment do
    fixed = 0

    Resource.where('fwd < ?', Date.new(1900, 1, 1)).find_each do |r|
      old = r.fwd
      r.update_column(:fwd, Date.new(old.year + 2000, old.month, old.day))
      puts "  ##{r.id} #{r.full_order_number} #{r.name}: fwd #{old} → #{r.fwd}"
      fixed += 1
    end

    Resource.where('checkin_date < ?', Date.new(1900, 1, 1)).find_each do |r|
      old = r.checkin_date
      r.update_column(:checkin_date, Date.new(old.year + 2000, old.month, old.day))
      puts "  ##{r.id} #{r.full_order_number} #{r.name}: checkin_date #{old} → #{r.checkin_date}"
      fixed += 1
    end

    puts "Fixed #{fixed} record(s)."
  end
end
