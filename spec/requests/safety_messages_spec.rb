require 'rails_helper'

RSpec.describe "SafetyMessages", type: :request do
  describe "GET /safety_messages" do
    it "works! (now write some real specs)" do
      get safety_messages_path
      expect(response).to have_http_status(200)
    end
  end
end
