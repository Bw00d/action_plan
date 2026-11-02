# Sample directory users (development only; loaded from db/seeds.rb).
# Idempotent: re-running updates these people instead of duplicating them.
# Everyone signs in with DEVELOPMENT_PASSWORD.

admin = User.find_by!(email: 'admin@test.com')
today = Date.current

def seed_incident(name, state, owner)
  Incident.find_or_create_by!(name: name) do |i|
    i.state = state
    i.incident_type = 'Wildfire'
    i.owner = owner
  end
end

cedar  = seed_incident('Cedar Ridge Fire', 'OR', admin)
bear   = seed_incident('Bear Gulch Complex', 'ID', admin)
pine   = seed_incident('Pine Hollow Fire', 'WA', admin)
juniper = seed_incident('Juniper Flats Fire', 'NV', admin)

people = [
  {
    email: 'jordan.reyes@example.com', first_name: 'Jordan', last_name: 'Reyes',
    home_unit: 'ORCOF', dispatch_center: 'ORCOC', time_zone: 'America/Los_Angeles',
    availability: :available,
    emergency: ['Sam Reyes', 'Spouse', '541-555-0144'],
    contacts: [[:phone, 'Cell', '541-555-0123', true], [:email, 'Work', 'jordan.reyes@example.com', true],
               [:phone, 'Home', '541-555-0199', false]],
    quals: [['OSC2', :qualified, :certified], ['DIVS', :qualified, :certified],
            ['TFLD', :qualified, :certified], ['OSC1', :trainee, :certified]],
    assignments: [[cedar, 'OSC2', today - 6, nil], [bear, 'DIVS', today - 60, today - 47],
                  [pine, 'DIVS', today - 120, today - 106]]
  },
  {
    email: 'maria.delgado@example.com', first_name: 'Maria', last_name: 'Delgado',
    home_unit: 'MTLNF', dispatch_center: 'MTMDC', time_zone: 'America/Denver',
    availability: :available,
    emergency: ['Luis Delgado', 'Brother', '406-555-0110'],
    contacts: [[:email, 'Personal', 'maria.delgado@example.com', true], [:phone, 'Cell', '406-555-0187', false]],
    quals: [['RESL', :qualified, :certified], ['SCKN', :qualified, :certified],
            ['PSC2', :trainee, :self_reported], ['SITL', :qualified, :self_reported]],
    assignments: [[juniper, 'RESL', today - 40, today - 27]]
  },
  {
    email: 'sam.whitehorse@example.com', first_name: 'Sam', last_name: 'Whitehorse',
    home_unit: 'AZFTA', dispatch_center: 'AZSDC', time_zone: 'America/Phoenix',
    availability: :unavailable, available_on: today + 10,
    emergency: ['Ana Whitehorse', 'Mother', '928-555-0131'],
    contacts: [[:phone, 'Cell', '928-555-0156', true]],
    quals: [['DIVS', :qualified, :certified], ['STEN', :qualified, :certified], ['ENGB', :qualified, :certified]],
    assignments: [[bear, 'STEN', today - 75, today - 62]]
  },
  {
    email: 'kelly.okafor@example.com', first_name: 'Kelly', last_name: 'Okafor',
    home_unit: 'IDBOD', dispatch_center: 'IDBDC', time_zone: 'America/Boise',
    availability: :available,
    emergency: ['Chris Okafor', 'Spouse', '208-555-0172'],
    contacts: [[:phone, 'Cell', '208-555-0164', true], [:email, 'Work', 'kelly.okafor@example.com', true]],
    quals: [['LSC2', :qualified, :certified], ['SPUL', :qualified, :self_reported],
            ['ORDM', :qualified, :self_reported]],
    assignments: []
  },
  {
    email: 'chris.nakamura@example.com', first_name: 'Chris', last_name: 'Nakamura',
    home_unit: 'WAOWF', dispatch_center: 'WACWC', time_zone: 'America/Los_Angeles',
    availability: :available,
    emergency: ['Emi Nakamura', 'Partner', '509-555-0118'],
    # Nothing shared, to show a profile with no contact buttons.
    contacts: [[:phone, 'Cell', '509-555-0140', false], [:email, 'Work', 'chris.nakamura@example.com', false]],
    quals: [['HEB1', :qualified, :certified], ['HLCO', :trainee, :certified], ['HMGB', :qualified, :self_reported]],
    assignments: [[pine, 'HEB1', today - 110, today - 97]]
  },
  {
    email: 'dana.fitzgerald@example.com', first_name: 'Dana', last_name: 'Fitzgerald',
    home_unit: 'COSJF', dispatch_center: 'CODRC', time_zone: 'America/Denver',
    availability: :available,
    emergency: ['Pat Fitzgerald', 'Father', '970-555-0103'],
    contacts: [[:phone, 'Cell', '970-555-0125', true]],
    quals: [['FSC2', :qualified, :certified], ['TIME', :qualified, :certified], ['COST', :trainee, :self_reported]],
    assignments: [[bear, 'TIME', today - 3, nil]]
  }
]

people.each do |p|
  user = User.find_or_initialize_by(email: p[:email])
  if user.new_record?
    user.password = user.password_confirmation = DEVELOPMENT_PASSWORD
    user.confirmed_at = Time.current
  end
  name, relation, phone = p[:emergency]
  user.update!(first_name: p[:first_name], last_name: p[:last_name], role: :user,
               home_unit: p[:home_unit], dispatch_center: p[:dispatch_center], time_zone: p[:time_zone],
               availability: p[:availability], available_on: p[:available_on],
               emergency_contact_name: name, emergency_contact_relation: relation,
               emergency_contact_phone: phone)

  user.contact_methods.destroy_all
  p[:contacts].each_with_index do |(kind, label, value, shared), i|
    user.contact_methods.create!(kind: kind, label: label, value: value, shared: shared, position: i)
  end

  p[:quals].each do |code, status, source|
    qual = user.qualifications.find_or_initialize_by(position: Position.find_by!(code: code))
    qual.update!(status: status, source: source,
                 certified_by: source == :certified ? admin : nil,
                 certified_at: source == :certified ? Time.current : nil)
  end

  # Overhead resources with the user's email link to the account on save
  # (Resource#link_user), the same way real check-ins do.
  p[:assignments].each do |incident, position, fwd, release_date|
    order = (900 + user.id).to_s
    resource = incident.resources.find_or_initialize_by(category: 'OVERHEAD', order_number: order)
    resource.update!(name: user.full_name, leader: user.full_name, position: position, agency: 'USFS',
                     number_personnel: 1, assignment_length: 14, fwd: fwd, release_date: release_date,
                     email: user.email)
  end
end

puts "Directory seeds: #{people.size} sample users."
