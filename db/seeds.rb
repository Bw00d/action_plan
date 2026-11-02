unless Rails.env.development?
  class ForbiddenDBSeedError < StandardError; end
  raise ForbiddenDBSeedError,
        "You should not seed the #{Rails.env} environment database."
end

DEVELOPMENT_PASSWORD = 'Devpass1'

# the production environment as this file (wich contains clear text passwords)
# is available at the Git repository.
# find_or_create_by! so `rails db:seed` can be re-run on an existing
# development database.
[
  {
    # Admin
    # E-mail doesn't have to be valid as no e-mails are sent
    # in the development environment (we're using Letter Opener)
    email: 'admin@test.com',
    role: :admin,
    first_name: 'Admin',
    last_name: 'User'
  }, {
    # Ordinary user (non-admin)
    email: 'user@test.com',
    role: :user,
    first_name: 'Ordinary',
    last_name: 'User'
  }
].each do |attrs|
  User.find_or_create_by!(email: attrs[:email]) do |u|
    u.assign_attributes(attrs.except(:email))
    u.password = u.password_confirmation = DEVELOPMENT_PASSWORD
    # Required when using Devise's Confirmable module
    u.confirmed_at = Time.zone.today
  end
end

Position.load_catalog!
load Rails.root.join('db', 'seeds', 'directory.rb')
