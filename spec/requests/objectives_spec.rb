require 'rails_helper'

RSpec.describe "Objectives", type: :request do
  describe "GET /objectives" do
    it "works! (now write some real specs)" do
      get objectives_path
      expect(response).to have_http_status(200)
    end
  end
end
