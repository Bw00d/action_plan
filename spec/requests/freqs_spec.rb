require 'rails_helper'

RSpec.describe "Freqs", type: :request do
  describe "GET /freqs" do
    it "works! (now write some real specs)" do
      get freqs_path
      expect(response).to have_http_status(200)
    end
  end
end
