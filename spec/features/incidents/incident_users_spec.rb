require 'rails_helper'

RSpec.describe 'Incident users page', type: :feature, js: true do
  let(:user) { create(:user) }

  before do
    login_as(user, scope: :user)
    @first_incident = create(:incident, name: 'Boundary', user_id: user.id)
    @second_incident = create(:incident, name: 'Swamp Goat', user_id: user.id)
  end

  subject { page }

  describe 'Adding collaborators' do
    before do
      visit '/incidents'
      click_link "Boundary"
      click_link "Collaborators"
    end

    context 'it should display users names ' do

      # it 'has only one user before adding collaborations' do
      #   # expect(@first_incident.users.count).to eq(1)
      # end
        # it { should have_content(user.full_name) }
        it { have_content('(Owner)') }
        it { should have_content(user.email) }

        # it { have_content('Enter and email...') }
        # it { should have_button('Invite') }
    end

    # context 'allows the owner to add users and displays their names' do
    #   before do
    #     # click_link "Invite"
    #   end
    # end
  end
end