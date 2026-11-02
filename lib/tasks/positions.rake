namespace :positions do
  desc 'Load or refresh the NWCG position catalog from config/positions.yml'
  task load: :environment do
    before = Position.count
    Position.load_catalog!
    puts "Positions: #{Position.count} (#{Position.count - before} added)."
  end
end
