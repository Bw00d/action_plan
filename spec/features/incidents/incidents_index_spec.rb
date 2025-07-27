require 'rails_helper'

describe 'Incident Index Page', type: :feature, js: true do
  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:ordinary_user) { FactoryBot.create(:user) }

  # describe 'Before incidents are created', type: :feature, js: true do
  #   before { login_as(admin_user) }
    
  #   it 'Home page should have the link to incidents' do
  #     visit '/'
  #     expect(page).to have_link ('Incidents')
  #     click_link 'Incidents'
  #     expect(page).to have_title 'Action Plan | Incidents'
  #   end

  #   it 'Should prompt to add an incident' do
      
  #     visit '/incidents'
  #     expect(page).to have_text 'Begin by adding an incident.'
  #     expect(page).to have_link 'New Incident'
  #   end
  # end

  describe 'After incidents are created', type: :feature, js: true do
    before { login_as(admin_user) }
    let(:incident) { FactoryBot.create(:incident)}
    let(:another_incident) { FactoryBot.create(:incident)}
    before {
      update_incident_user_id(incident, admin_user)
      update_incident_user_id(another_incident, admin_user)
    }

    it 'should have a link to the incidents' do
      visit '/incidents'
      expect(page).to have_link (incident.name)
      expect(page).to have_link (another_incident.name)
    end

    it 'should link to the incident' do
      visit '/incidents'
      click_link (incident.name)
      expect(page).to have_title ("Action Plan | #{incident.name}")
    end
  end

end