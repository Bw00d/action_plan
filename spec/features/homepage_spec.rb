require 'rails_helper'

describe 'Home Page', type: :feature, js: true do
  let(:admin_user) { FactoryBot.create(:admin_user) }
  let(:ordinary_user) { FactoryBot.create(:user) }

  describe 'before signing in', type: :feature, js: true do 
    it 'should have the right title' do
      visit '/'
      expect(page).to have_title ('Action Plan | Home')
    end

    it 'should have the right links' do
      visit '/'
      expect(page).to have_link ('Sign in')
      expect(page).to have_link ('Sign up')
    end

    it 'should not have the signed in links' do
      visit '/'
      expect(page).not_to have_link ('Plans')
      expect(page).not_to have_link ('Incidents')
    end
  end

  describe 'before after signing in', type: :feature, js: true do
    before { login_as(admin_user) }
    it 'should have the right links' do
      visit '/'
      expect(page).to have_link ('Incidents')
      expect(page).to have_link (admin_user.first_name + " " + admin_user.last_name)
      expect(page).not_to have_link ('Sign in')
      expect(page).not_to have_link ('Sign up')
    end
  end


end
