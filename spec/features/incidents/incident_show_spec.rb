require 'rails_helper'

RSpec.describe 'Incident Show Page', type: :feature, js: true do
  let(:user) { create(:user) }

  before do
    login_as(user, scope: :user)
    create(:incident, name: 'Boundary', user_id: user.id)
    create(:incident, name: 'Swamp Goat', user_id: user.id)
  end

  subject { page }

  describe 'visiting the incident page' do 
    before do
      visit '/incidents'
      click_link "Boundary"
    end
    it { should have_title ("Action Plan | Boundary") }

    context 'it should have the right links' do
     it { should have_link 'IAP'}
     it { should have_link 'Resources'}
     it { should have_link 'Back'}
    end

    context 'it should display the incident name and type' do
      it { should have_text ("Boundary – Wildfire") }
    end

    context 'should display a share link' do
      it { should have_link 'Collaborators'}
    end

    context 'there should have a resource panel' do
      it { should have_content 'There are no resources assigned to this incident.'}
      it { should have_link('') { have_css('#new-resource') } } 
      it { should_not have_css('#resource-form') }
      
    end

    describe 'clicking the new resource link' do
      before do
        find('#new-resource').click
      end

      context 'it should display the new resource form' do
        it { should have_css('#resource-form') }
        it { should have_link('') { have_css('#new-resource') } } 
      end
    end
  end

  describe 'adding collaborators' do
    before do
      visit '/incidents'
      click_link "Boundary"
      click_link "Collaborators"
    end

    context 'it should bring you to incident users page' do
      it { have_content('Enter and email...') }
      it { should have_button('Invite') }
      it { should have_content(user.full_name) }
      it { should have_content(user.email) }
    end
  end

  
end
