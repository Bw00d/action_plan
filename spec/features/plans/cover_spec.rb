require 'rails_helper'

describe 'IAP Cover', type: :feature, js: true do
  before do 
    user = create_and_signin_user
    incident = create_new_incident(user)
    
    # Navigate to the incidents page if not already there
    visit incidents_path
    
    # Wait for the page to load and check if we're on the right page
    expect(page).to have_content('Swamp Goat')
    
    click_link 'Swamp Goat'
    click_link 'IAP' 
    
    # Fill in the date and close the datepicker
    fill_in 'Date', with: Date.today.strftime("%m/%d/%Y")
    
    # Press escape or tab to close the datepicker
    find('#plan_date').send_keys(:tab)
    
    # Alternative: use JavaScript to hide the datepicker
    page.execute_script("$('.datepicker').hide();")
    
    # Wait a moment for UI to settle
    sleep 0.5
    
    # Scroll the button into view and click it
    button = find('input[value="Create Plan"]')
    page.execute_script("arguments[0].scrollIntoView(true);", button)
    button.click
  end
    

  it 'should have the right title' do
    expect(page).to have_title ('Action Plan | The Plan')
  end

  it 'should create a new plan' do
    expect(page).to have_content (Date.today.strftime("%-m/%d"))
  end

  it 'should have a link to create another plan' do
    expect(page).to have_link ('New')
  end


end
