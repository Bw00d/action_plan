require 'rails_helper'

describe 'Contact form via UI', type: :feature, js: true do
  let(:admin_user) { FactoryGirl.create(:admin_user) }
  let(:ordinary_user) { FactoryGirl.create(:user) }

  it 'should have the right title' do
    visit '/'
    expect(page).to have_title ('Action Plan | Home')
  end

end
