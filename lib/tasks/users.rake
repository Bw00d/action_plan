# Bot-account clean-up. Lists users whose first AND last names are random
# letter strings (see FakeUsers.random_name?), and deletes the ones with
# no data attached. Admins and anyone referenced elsewhere are never
# deleted; they're listed for manual review instead.
#
# Run:
#   bin/rails users:purge_fake             # preview only, no changes
#   CONFIRM=1 bin/rails users:purge_fake   # delete the safe matches
#
# On Heroku:
#   heroku run rails users:purge_fake
#   heroku run CONFIRM=1 rails users:purge_fake
namespace :users do
  desc 'Delete users with random-string names and no data (preview unless CONFIRM=1)'
  task purge_fake: :environment do
    confirm = ENV['CONFIRM'] == '1'
    safe = []
    held = []

    FakeUsers.candidates.each do |user|
      refs = FakeUsers.references(user)
      refs.empty? ? safe << user : held << [user, refs]
    end

    line = lambda do |u|
      status = u.confirmed? ? 'confirmed' : 'unconfirmed'
      format('  #%-6d %-40s %-45s %s, %d sign-ins, created %s',
             u.id, u.email, u.full_name, status, u.sign_in_count.to_i, u.created_at.to_date)
    end

    puts "=== Fake user clean-up (#{confirm ? 'DELETING' : 'PREVIEW — nothing will be deleted'}) ==="
    puts "\nNo data attached, #{confirm ? 'deleting' : 'would delete'} (#{safe.size}):"
    safe.each { |u| puts line.call(u) }

    if held.any?
      puts "\nRandom-looking name but has data, NOT deleted — check by hand (#{held.size}):"
      held.each { |u, refs| puts "#{line.call(u)}\n           referenced in: #{refs.join(', ')}" }
    end

    unless confirm
      puts "\nPreview only. Run again with CONFIRM=1 to delete the #{safe.size} users above."
      next
    end

    deleted = 0
    safe.each do |user|
      user.destroy!
      deleted += 1
    rescue StandardError => e
      puts "  could not delete ##{user.id} #{user.email}: #{e.class}: #{e.message}"
    end
    puts "\nDeleted #{deleted} of #{safe.size} users."
  end
end
