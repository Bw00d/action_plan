require 'rails_helper'

describe 'Incident Show', type: :feature, js: true do
  let(:admin_user) { FactoryGirl.create(:admin_user) }
  let(:ordinary_user) { FactoryGirl.create(:user) }

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
