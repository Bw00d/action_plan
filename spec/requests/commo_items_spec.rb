require 'rails_helper'

RSpec.describe "CommoItems", type: :request do
  describe "GET /commo_items" do
    it "works! (now write some real specs)" do
      get commo_items_path
      expect(response).to have_http_status(200)
    end
  end
end
