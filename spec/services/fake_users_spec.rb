require 'rails_helper'
require 'rake'

RSpec.describe FakeUsers do
  describe '.random_part?' do
    it 'matches bot-generated names' do
      %w[xYmqTkyizxHNMdHnCtdrLFH ypmMlExulExgKITeav rKAvJkWinKseuJUa aUJDxOrPrxbDTdHH].each do |name|
        expect(described_class.random_part?(name)).to be(true), name
      end
    end

    it 'leaves real names alone' do
      %w[Christopher McDonald DeLaCruz Pending Invitee Montgomery-Smith OConnorJones].each do |name|
        expect(described_class.random_part?(name)).to be(false), name
      end
    end
  end

  describe 'users:purge_fake' do
    before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

    let!(:bot)     { create(:user, first_name: 'rKAvJkWinKseuJUa', last_name: 'aUJDxOrPrxbDTdHH') }
    let!(:active)  { create(:user, first_name: 'xYmqTkyizxHNMdHnCtdrLFH', last_name: 'ypmMlExulExgKITeav') }
    let!(:real)    { create(:user, first_name: 'Pat', last_name: 'Lee') }
    let!(:admin)   { create(:admin_user, first_name: 'qWeRtYuIoPa', last_name: 'zXcVbNmAsDf') }

    before { create(:incident).users << active }

    def run_task(confirm:)
      ENV['CONFIRM'] = confirm ? '1' : nil
      task = Rake::Task['users:purge_fake']
      task.reenable
      expect { task.invoke }.to output.to_stdout
    ensure
      ENV.delete('CONFIRM')
    end

    it 'deletes nothing without CONFIRM=1' do
      expect { run_task(confirm: false) }.not_to change(User, :count)
    end

    it 'deletes only random-named users with no data, never admins' do
      run_task(confirm: true)

      expect(User.exists?(bot.id)).to be(false)
      expect(User.exists?(active.id)).to be(true)
      expect(User.exists?(real.id)).to be(true)
      expect(User.exists?(admin.id)).to be(true)
    end
  end
end
