require 'rails_helper'

describe 'Index page', type: :feature, js: true do
    before do 
      create_and_signin_user
      click_link 'Plan' 
    end
    

  it 'should have the right title' do
    expect(page).to have_title ('Action Plan | The Plan')
  end

  it 'should have a link to create new plan for today' do
    expect(page).to have_link ('New')
  end

  it 'should create a new plan when "New" button is clicked' do
    click_link 'New'
    expect(page).to have_content (Date.today.strftime("%-m/%d"))
    expect(page).not_to have_link ('New')
  end

end
