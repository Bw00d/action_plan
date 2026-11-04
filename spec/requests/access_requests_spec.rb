require 'rails_helper'

RSpec.describe 'Access requests', type: :request do
  include ActiveJob::TestHelper

  let(:valid_params) do
    { access_request: { first_name: 'Pat', last_name: 'Lee', email: 'Pat.Lee@example.com',
                        position: 'RESL' } }
  end

  describe 'closed sign-up' do
    it 'sends the sign-up page to the request form' do
      get new_user_registration_path
      expect(response).to redirect_to(new_access_request_path)
    end

    it 'creates no account when the sign-up form is posted' do
      expect {
        post user_registration_path, params: { user: { email: 'bot@example.com', password: 'Password1',
                                                       password_confirmation: 'Password1',
                                                       first_name: 'x', last_name: 'y' } }
      }.not_to change(User, :count)
      expect(response).to redirect_to(new_access_request_path)
    end
  end

  describe 'links and form' do
    it 'offers Request access instead of Sign up to guests' do
      get new_user_session_path
      expect(response.body).to include(new_access_request_path)
      expect(response.body).not_to include('Sign up')
    end

    it 'renders the request form' do
      get new_access_request_path
      expect(response.body).to include('ICS function or position', 'name="website"')
    end

    it 'shows admins a badge for pending requests' do
      AccessRequest.create!(first_name: 'Pat', last_name: 'Lee', email: 'pat@example.com', position: 'RESL')
      login_admin
      get root_path
      expect(response.body).to match(%r{dropdown-toggle nav-feed-link.*?<span class="feed-badge">1</span>}m)
      expect(response.body).to match(%r{href="/admin/access_requests">.*?<span class="badge">1</span>}m)
    end
  end

  describe 'POST /access_requests' do
    let!(:admin) { create(:admin_user) }

    # Creating the admin above sends Devise mail; start each test clean.
    before { ActionMailer::Base.deliveries.clear }

    it 'saves the request and emails only the admins' do
      perform_enqueued_jobs { post access_requests_path, params: valid_params }

      expect(response).to redirect_to(new_user_session_path)
      expect(AccessRequest.pending.last.email).to eq('pat.lee@example.com')
      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[admin.email]])
    end

    it 'quietly drops a submission with the honeypot filled in' do
      expect {
        perform_enqueued_jobs { post access_requests_path, params: valid_params.merge(website: 'spam') }
      }.not_to change(AccessRequest, :count)
      expect(response).to redirect_to(new_user_session_path)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it 'rejects a second pending request for the same email' do
      post access_requests_path, params: valid_params
      expect { post access_requests_path, params: valid_params }.not_to change(AccessRequest, :count)
      expect(response.body).to include('already has a request waiting for review')
    end
  end

  describe 'admin review' do
    let(:access_request) do
      AccessRequest.create!(first_name: 'Pat', last_name: 'Lee', email: 'pat@example.com', position: 'RESL')
    end

    it 'is forbidden to ordinary users' do
      login_user
      post approve_admin_access_request_path(access_request)
      expect(response).to have_http_status(:forbidden)
      expect(access_request.reload).to be_pending
    end

    context 'as an admin' do
      before do
        login_admin
        ActionMailer::Base.deliveries.clear
      end

      it 'lists pending requests' do
        access_request
        get admin_access_requests_path
        expect(response.body).to include('pat@example.com')
      end

      it 'approves by creating the account and emailing a set-password link' do
        perform_enqueued_jobs { post approve_admin_access_request_path(access_request) }

        user = User.find_by(email: 'pat@example.com')
        expect(user.full_name).to eq('Pat Lee')
        expect(user).not_to be_confirmed
        expect(access_request.reload).to be_approved
        mail = ActionMailer::Base.deliveries.last
        expect(mail.to).to eq(['pat@example.com'])
        expect(mail.text_part.body.to_s).to include('/invitations/')
      end

      it 'gives an existing unconfirmed account a fresh link and the requested name' do
        bot = create(:user, email: 'pat@example.com', first_name: 'rKAvJk', last_name: 'aUJDxO')
        bot.update_columns(confirmed_at: nil)
        perform_enqueued_jobs { post approve_admin_access_request_path(access_request) }

        expect(bot.reload).not_to be_confirmed
        expect(bot.full_name).to eq('Pat Lee')
        expect(ActionMailer::Base.deliveries.last.text_part.body.to_s).to include('/invitations/')
      end

      it 'declines without emailing the requester' do
        perform_enqueued_jobs { post decline_admin_access_request_path(access_request) }

        expect(access_request.reload).to be_declined
        expect(ActionMailer::Base.deliveries).to be_empty
        expect(User.find_by(email: 'pat@example.com')).to be_nil
      end
    end
  end
end
