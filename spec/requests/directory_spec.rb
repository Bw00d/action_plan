require 'rails_helper'

RSpec.describe 'Directory', type: :request do
  let(:osc2) { create(:position, code: 'OSC2', title: 'Operations Section Chief Type 2') }
  let(:divs) { create(:position, code: 'DIVS', title: 'Division/Group Supervisor') }

  let!(:jordan) do
    create(:user, first_name: 'Jordan', last_name: 'Reyes', home_unit: 'ORCOF', dispatch_center: 'ORCOC',
                  emergency_contact_name: 'Sam Reyes', emergency_contact_phone: '541-555-0144',
                  emergency_contact_relation: 'Spouse')
  end
  let!(:maria) { create(:user, first_name: 'Maria', last_name: 'Delgado', home_unit: 'MTLNF', dispatch_center: 'MTMDC') }

  describe 'access' do
    it 'requires sign-in' do
      get directory_index_path
      expect(response).to redirect_to(new_user_session_path)
      get directory_path(jordan)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'leaves out unconfirmed accounts' do
      pending_user = create(:user, first_name: 'Pending', last_name: 'Invitee')
      pending_user.update_columns(confirmed_at: nil)
      login_user
      get directory_index_path
      expect(response.body).not_to include('Pending Invitee')
    end
  end

  describe 'emergency contact' do
    it 'is never sent to a non-admin' do
      login_user
      get directory_path(jordan)
      expect(response).to have_http_status(200)
      expect(response.body).not_to include('Sam Reyes', '541-555-0144', 'Spouse')
      expect(response.body).to include('Emergency contact visible to admins only')
    end

    it 'is hidden on your own public profile too' do
      login_as(jordan, scope: :user)
      get directory_path(jordan)
      expect(response.body).not_to include('Sam Reyes', '541-555-0144')
    end

    it 'is shown to admins' do
      login_admin
      get directory_path(jordan)
      expect(response.body).to include('Sam Reyes', '541-555-0144', 'Spouse')
    end
  end

  describe 'contact sharing' do
    before do
      create(:contact_method, user: jordan, kind: :phone, label: 'Cell', value: '541-555-0123', shared: true)
      create(:contact_method, user: jordan, kind: :phone, label: 'Home', value: '541-555-0199', shared: false)
      create(:contact_method, user: jordan, kind: :email, value: 'hidden@example.com', shared: false)
      login_user
    end

    it 'shows a Phone button that reveals shared numbers, and nothing hidden' do
      get directory_path(jordan)
      expect(response.body).to include('data-contact-toggle="phone"', '541-555-0123')
      expect(response.body).not_to include('data-contact-toggle="email"')
      expect(response.body).not_to include('541-555-0199', 'hidden@example.com')
    end

    it 'never links to the phone, text or mail apps' do
      create(:contact_method, user: jordan, kind: :email, value: 'jordan@example.com', shared: true)
      get directory_path(jordan)
      expect(response.body).to include('data-contact-toggle="email"', 'jordan@example.com')
      expect(response.body).not_to include('tel:', 'sms:', 'mailto:')
    end

    it 'renders no contact buttons when nothing is shared' do
      get directory_path(maria)
      expect(response.body).not_to include('data-contact-toggle')
    end
  end

  describe 'search and filters' do
    before do
      create(:qualification, user: jordan, position: osc2)
      create(:qualification, user: maria, position: divs)
      login_user
    end

    def names
      response.body.scan(%r{<span class="dir-row-name">([^<]+)</span>}).flatten
    end

    it 'finds by name' do
      get directory_index_path, params: { q: 'reyes' }
      expect(names).to eq(['Jordan Reyes'])
    end

    it 'finds by qualification code' do
      get directory_index_path, params: { q: 'divs' }
      expect(names).to eq(['Maria Delgado'])
    end

    it 'finds by home unit and by dispatch center' do
      get directory_index_path, params: { q: 'orcof' }
      expect(names).to eq(['Jordan Reyes'])
      get directory_index_path, params: { q: 'MTMDC' }
      expect(names).to eq(['Maria Delgado'])
    end

    it 'filters by qualification' do
      get directory_index_path, params: { qual: 'OSC2' }
      expect(names).to eq(['Jordan Reyes'])
    end

    it 'filters by status, with On assignment taken from a current check-in' do
      maria.update!(availability: :unavailable)
      create(:resource, category: 'OVERHEAD', email: jordan.email, fwd: Date.current - 2, assignment_length: 14)

      get directory_index_path, params: { status: 'on_assignment' }
      expect(names).to eq(['Jordan Reyes'])
      get directory_index_path, params: { status: 'unavailable' }
      expect(names).to eq(['Maria Delgado'])
      get directory_index_path, params: { status: 'available' }
      expect(names).not_to include('Jordan Reyes', 'Maria Delgado')
    end

    it 'shows up to three qualification badges and a status badge per row' do
      [create(:position, code: 'TFLD'), create(:position, code: 'STEN'), create(:position, code: 'ENGB')].each do |pos|
        create(:qualification, user: jordan, position: pos)
      end
      get directory_index_path, params: { q: 'reyes' }
      row = response.body[/<a class="dir-row".*?<\/a>/m]
      expect(row.scan('class="dir-qual').size).to eq(3)
      expect(row).to include('dir-status--available')
    end
  end

  describe 'profile page' do
    it 'shows the current incident, quals with their status, and recent assignments' do
      incident = create(:incident, name: 'Cedar Ridge Fire', state: 'OR')
      create(:resource, incident: incident, category: 'OVERHEAD', position: 'OSC2', email: jordan.email,
                        fwd: Date.current - 3, assignment_length: 14)
      create(:qualification, user: jordan, position: osc2)
      create(:qualification, user: jordan, position: divs, status: :trainee)
      login_user

      get directory_path(jordan)
      body = response.body
      expect(body).to include('On assignment', 'Cedar Ridge Fire, OR')
      expect(body).to include((Date.current + 11).strftime('%b %-d')) # day after LWD
      expect(body).to include('OSC2 · Operations Section Chief Type 2', 'Qualified')
      expect(body).to include('DIVS · Division/Group Supervisor', 'Trainee · PTB open')
      expect(body).not_to include('Certified', 'Self-reported')
    end
  end
end
