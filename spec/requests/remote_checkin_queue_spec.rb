require 'rails_helper'

RSpec.describe 'Remote check-in queue: unmatched submissions', type: :request do
  before { login_user }

  let(:incident) { create(:incident) }
  let!(:rc) do
    incident.remote_checkins.create!(
      req_number_raw: 'C-14', name: 'Hotshot 7', position: 'CRWB', agency: 'BLM',
      leader: 'Sam Roe', phone: '907-555-0101', number_personnel: 20, submitted_at: Time.current
    )
  end

  def create_request(req_number, catalog: 'Crew')
    incident.requests.create!(iroc_req_id: "IROC-#{req_number}", req_number: req_number,
                              req_catalog_name: catalog)
  end

  it 'starts unmatched and offers Match again and Check in anyway' do
    get incident_remote_checkins_path(incident)
    expect(response.body).to include('Match again', 'Check in anyway',
                                      incident_remote_checkin_checkin_path(incident, rc))
  end

  describe 'Match again' do
    it 'links the request once it has been imported' do
      req = create_request('C-14')
      post rematch_incident_remote_checkin_path(incident, rc)
      expect(response).to redirect_to(incident_remote_checkins_path(incident))
      expect(rc.reload.request).to eq(req)
      expect(flash[:notice]).to include('Matched')
    end

    it 'says so when there is still no request' do
      post rematch_incident_remote_checkin_path(incident, rc)
      expect(rc.reload.request).to be_nil
      expect(flash[:alert]).to include('Still no request C-14')
    end
  end

  describe 'Check in anyway' do
    it 'opens the check-in form pre-filled from the submission' do
      get incident_remote_checkin_checkin_path(incident, rc)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No matching request', 'value="Hotshot 7"', 'value="14"',
                                        'value="Sam Roe"', '<option selected="selected" value="CREW">')
    end

    let(:form_params) do
      { remote_checkin_id: rc.id,
        resource: { name: 'Hotshot 7', category: 'CREW', position: 'CRWB', order_number: '41',
                    agency: 'BLM', number_personnel: 20, checkin_date: Date.current,
                    fwd: Date.current, assignment_length: 14 } }
    end

    it 'checks in with a corrected number and links the matching request' do
      req = create_request('C-41')
      create_request('C-41.1')

      expect {
        post incident_remote_checkin_checkin_path(incident, rc), params: form_params
      }.to change(Resource, :count).by(1)

      resource = Resource.last
      expect(response).to redirect_to(incident_remote_checkins_path(incident))
      expect(resource.full_order_number).to eq('C-41')
      expect(resource.rosters.count).to eq(1)
      expect(rc.reload).to have_attributes(status: 'promoted', promoted_resource: resource, request: req)
    end

    it 'checks in even when no request matches' do
      post incident_remote_checkin_checkin_path(incident, rc), params: form_params
      expect(rc.reload).to have_attributes(status: 'promoted', request: nil)
    end

    it 'is not reachable without a submission' do
      expect {
        get incident_remote_checkin_checkin_path(incident, 0)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
