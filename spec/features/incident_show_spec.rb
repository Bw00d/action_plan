require 'rails_helper'

describe 'Incident Show', type: :feature, js: true do
  let(:admin_user) { FactoryBot.create(:admin_user) }
  before { login_as(admin_user) }
  let(:incident) { FactoryBot.create(:incident)}
  before { 
    update_incident_user_id(incident, admin_user)
    visit '/incidents'
    click_link incident.name
     }

  it 'should have the right title' do
    expect(page).to have_title ("Action Plan | #{incident.name}")
  end

  it 'should have the right links' do
    expect(page).to have_link ('Action Plan')
    expect(page).to have_link ('Back')
  end

  it 'should display the incident name and type' do

  end

end
