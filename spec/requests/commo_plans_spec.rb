require 'rails_helper'

RSpec.describe "CommoPlans", type: :request do
  describe "GET /commo_plans" do
    it "works! (now write some real specs)" do
      get commo_plans_path
      expect(response).to have_http_status(200)
    end
  end
end
