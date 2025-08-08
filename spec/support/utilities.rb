include ApplicationHelper

def create_and_signin_user
  user = FactoryBot.create(:user)
  user.confirm # Confirm the user for Devise confirmable
  visit new_user_session_path
  fill_in "user_email",    with: user.email
  fill_in "user_password", with: user.password
  click_button "Sign in"
  
  # Wait for redirect after sign in
  expect(page).to have_current_path(root_path)
  
  user
end

def seed_plans
  user = FactoryBot.create(:user)
  plan1 = Plan.create(user_id: user.id, date: "Sat, 20 Jun 2019 02:18:11 UTC +00:00")
  plan2 = Plan.create(user_id: user.id, date: "Sat, 19 Jun 2019 02:18:11 UTC +00:00")
  plan3 = Plan.create(user_id: user.id, date: "Sat, 18 Jun 2019 02:18:11 UTC +00:00")
end

def update_incident_user_id(incident, user)
  incident.update_attributes(user_id: user.id)
end

def create_incident
  click_link "New Incident"
  
  # Make all form sections visible
  page.execute_script("$('.form-attributes').show()")
  
  # Wait a moment for animations/transitions
  sleep 0.5
  
  # Fill fields
  fill_in 'incident_name', with: "Big Fire"
  
  within('.form-incident-type') do
    find('select[name="incident[incident_type]"]').select('Wildfire')
  end
  
  within('.form-incident-complexity') do
    find('select[name="incident[complexity]"]').select('Type 3')
  end
  
  # Use JavaScript to fill the location field if Capybara can't interact with it
  page.execute_script("document.getElementById('incident_location').value = 'Boise, ID'")
  # Trigger change event to ensure any JavaScript listeners fire
  page.execute_script("$('#incident_location').trigger('change')")
  
  fill_in 'incident_start_date', with: Date.today.strftime("%m/%d/%Y")
  
  # Make the submit button visible if it's hidden
  page.execute_script("$('input[type=\"submit\"]').parent().css('visibility', 'visible')")
  
  click_button 'CREATE INCIDENT'
end

def create_new_incident(user) Incident.create!(name: "Swamp Goat", incident_type: "Wildfire", 
    complexity: "Type 3", location: "Fairbanks, AK", user_id: user.id, start_date: Date.today) 
end

def add_resource(options = {})
  # Default values - can be overridden by passing options
  resource_data = {
    name: "Test Resource",
    position: "Engine Boss",
    category: "EQUIPMENT",
    order_number: "12", # the prefix E- will be supplied by jquery
    leader: "John Smith",
    number_personnel: "3",
    agency: "PRI",
    checkin_date: Date.today.strftime("%m/%d/%Y"),
    fwd: Date.tomorrow.strftime("%m/%d/%Y"),
    assignment_length: "14"
  }.merge(options)
  
  # Fill in the form fields
  fill_in 'resource_name', with: resource_data[:name]
  fill_in 'resource_position', with: resource_data[:position]
  
  # Select from dropdown
  select resource_data[:category], from: 'resource_category'
  sleep 0.5
  
  fill_in 'resource_order_number', with: resource_data[:order_number]
  fill_in 'resource_leader', with: resource_data[:leader]
  fill_in 'resource_number_personnel', with: resource_data[:number_personnel]
  fill_in 'resource_agency', with: resource_data[:agency]
  
  # Date fields
  fill_in 'incident_checkin_date', with: resource_data[:checkin_date]
  fill_in 'incident_fwd', with: resource_data[:fwd]
  
  # Note: Both fwd and assignment_length have the same id in your form (incident_fwd)
  # This might cause issues. For now, using the name attribute
  fill_in 'resource_assignment_length', with: resource_data[:assignment_length]
  
  # Submit the form
  click_button 'Submit'
  
  # Since it's a remote: true form, you might want to wait for the AJAX request
  # Adjust the expectation based on what happens after successful submission
end