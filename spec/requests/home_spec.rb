require 'rails_helper'

RSpec.describe 'Home page', type: :request do
  context 'when signed out' do
    it 'shows the Planning P and not the Welcome guide' do
      get root_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('Tactics Meeting')
      expect(response.body).not_to include('Welcome to Action Plan')
    end
  end

  context 'when signed in as a user' do
    before { login_user }

    it 'shows the Welcome guide without the admin section' do
      get root_path
      expect(response).to have_http_status(200)
      expect(response.body).to include('Welcome to Action Plan')
      expect(response.body).not_to include('guide-admin')
    end
  end

  context 'when signed in as an admin' do
    before { login_admin }

    it 'includes the admin section' do
      get root_path
      expect(response.body).to include('guide-admin')
    end
  end
end
