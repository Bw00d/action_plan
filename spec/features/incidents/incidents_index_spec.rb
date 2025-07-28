require 'rails_helper'

RSpec.describe 'Incidents', type: :feature, js: true do
  let(:user) { create(:user) }

  before do
    login_as(user, scope: :user)
  end

  describe 'incidents index page' do
    context 'when no incidents exist' do
      it 'shows empty state message and new incident button' do
        visit incidents_path
        
        expect(page).to have_content('Begin by adding an incident.')
        expect(page).to have_link('New Incident')
      end
    end

    context 'when incidents already exist' do
      before do
        create(:incident, name: 'Forest Fire', user_id: user.id)
        create(:incident, name: 'Grass Fire', user_id: user.id)
      end

      it 'displays all incidents' do
        visit incidents_path
        
        expect(page).not_to have_content('Begin by adding an incident.')
        expect(page).to have_link('Forest Fire')
        expect(page).to have_link('Grass Fire')
      end
    end
  end
end