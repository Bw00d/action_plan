require 'rails_helper'

describe 'Resources Page', type: :feature  do
  let(:admin_user) { FactoryBot.create(:admin_user) }
  before { login_as(admin_user) }
  let(:incident) { FactoryBot.create(:incident)}
  before do 
    update_incident_user_id(incident, admin_user)
    visit "/incidents/#{incident.id}/resources"
     end

 subject { page }

  describe 'The visiting the resources page with no assigned resources' do 
      context 'It should have the right title' do
      it { should have_title ('Action Plan | Resources') }
    end

      context 'The page should have the right tab links' do
        it { should have_link("ICS-211")}
        it { should have_link("Glide Path")}
        it { should have_link("Demob List")}
        it { should have_link("Resource Tally")}
      end

    context 'It should have a notice that no resources are assigned' do
      it { should have_text ('There are no resources assigned to this incident.')}
    end
  end

  describe 'Describe adding resources to the page', type: :feature, js: true do
    
    scenario 'When clicking new resource link it should show the resource form' do
      before { find("#new-resource").click }
      it { should have_text 'New Resource'}
    end

    describe 'When filing in form it should create a new resource' do 
        find("#new-resource").click 
        fill_in '#resource_name', with: 'Jim Dandy'
        select 'OVERHEAD', from: '#resource_category'
        fill_in "RESOURCE KIND/TYPE", with: 'SITL'
        fill_in "CHECKIN DATE", with: Date.today
        fill_in "FIRST WORK DAY", with: Date.today
        fill_in "ASSIGNMENT LENGTH", with: 14
      it { should have_text "Jim Dandy" }
    end
  end

  # describe 'Signing as admin', type: :feature, js: true do
  #   before { login_as(admin_user) }
  #   it 'should have the right links' do
  #     visit '/'
  #     it { should have_link ('Incidents')}
  #     it { should have_link ('Users')}
  #     it { should have_link (admin_user.first_name + " " + admin_user.last_name)}
  #     it { should_not have_link ('Sign in')}
  #     it { should_not have_link ('Sign up')}
  #   end
  # end


end
