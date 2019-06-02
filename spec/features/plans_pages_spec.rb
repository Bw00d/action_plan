require 'rails_helper'

describe 'Index page', type: :feature, js: true do


  it 'should have the right title' do
    create_and_signin_user
    click_link 'Plan'
    expect(page).to have_title ('Action Plan | The Plan')
  end

end
