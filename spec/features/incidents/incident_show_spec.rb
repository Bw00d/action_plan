require 'rails_helper'
include Warden::Test::Helpers
Warden.test_mode!

feature 'Incident pages', :devise do

  after(:each) do
    Warden.test_reset!
  end

  before(:each) do 
    @admin_user =  FactoryBot.create(:admin_user)
    login_as(@admin_user, scope: :user) 

  end 


  describe 'creating and incident', js: true do 
    before do
      create_new_incident(@admin_user)
      visit '/incidents'
    end
    
  subject { page }

    it 'creates the incident' do
      expect(Incident.count).to  eq(1)
    end
  end

  describe 'visiting the incident page' do 
    before do
      visit '/incidents'
      click_link "Swamp Goat"
    end
    it { should have_title ("Action Plan | #{@incident.name}") }
  end



  # it 'should have the right links' do
  #   expect(page).to have_link ('Action Plan')
  #   expect(page).to have_link ('Back')
  # end

  # it 'should display the incident name and type' do
  #   expect(page).to have_text ("#{incident.name} – #{incident.incident_type}")
  # end

  # it 'should display a share link' do
  #   expect(page).to have_link 'Invite'
  # end

end
