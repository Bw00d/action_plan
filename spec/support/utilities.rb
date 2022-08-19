include ApplicationHelper

def create_and_signin_user
  user = FactoryBot.create(:user)
  visit new_user_session_path
  fill_in "user_email",    with: user.email
  fill_in "user_password", with: user.password
  click_button "Sign in"
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