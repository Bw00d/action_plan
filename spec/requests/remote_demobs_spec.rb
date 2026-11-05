require 'rails_helper'

RSpec.describe 'Remote demobs', type: :request do
  let(:incident) { create(:incident) }
  let(:token) { incident.reload.remote_checkin_token }
  let!(:resource) do
    create(:resource, incident: incident, category: 'EQUIPMENT',
                      order_number: '12', name: 'Engine 5', phone: '907-555-0100',
                      transportation_method: 'Private Vehicle')
  end

  # Answers the current question and follows the redirect.
  def answer(value)
    post remote_demob_path(token), params: { answer: value }
    follow_redirect! if response.redirect?
  end

  def walk_form(req_number:, ron:)
    get remote_demob_path(token)
    answer req_number
    answer 'Pat Lee'
    answer '907-555-0199'
    answer 'AOV'
    answer '2026-11-06T08:30'
    answer 'Fairbanks, AK'
    answer ron ? 'true' : 'false'
    answer 'Tok, AK' if ron
    answer '2026-11-07T14:00'
  end

  describe 'public form' do
    it 'rejects an unknown token' do
      get remote_demob_path('nope')
      expect(response).to have_http_status(:not_found)
    end

    it 'pre-fills name, phone and travel method from the matched resource' do
      get remote_demob_path(token)
      answer 'e 12'
      expect(response.body).to include('We found', 'E-12', 'value="Engine 5"')
      answer 'Engine 5'
      expect(response.body).to include('value="907-555-0100"')
      answer '907-555-0100'
      expect(response.body).to include('<option value="POV" selected>Privately Owned Vehicle</option>')
    end

    it 'asks for the RON location only when staying overnight' do
      walk_form(req_number: 'E-12', ron: false)
      expect(response.body).to include('Review your answers')
      expect(response.body).not_to include('RON City')
    end

    it 'saves a submission linked to the resource' do
      walk_form(req_number: 'E-12', ron: true)
      expect(response.body).to include('Yes — Tok, AK', 'Agency Vehicle')

      expect {
        post remote_demob_path(token), params: { commit_submission: '1' }
      }.to change(RemoteDemob, :count).by(1)
      expect(response).to redirect_to(remote_demob_thanks_path(token))

      rd = RemoteDemob.last
      expect(rd).to have_attributes(
        resource: resource, req_number_raw: 'E-12', name: 'Pat Lee', phone: '907-555-0199',
        travel_method: 'AOV', travel_start_date: Date.new(2026, 11, 6),
        travel_start_time: '0830', destination: 'Fairbanks, AK', ron: true,
        ron_location: 'Tok, AK', arrival_date: Date.new(2026, 11, 7), arrival_time: '1400',
        status: 'pending'
      )
    end

    it 'keeps an unmatched request number for Plans to sort out' do
      walk_form(req_number: 'O-999', ron: false)
      post remote_demob_path(token), params: { commit_submission: '1' }
      expect(RemoteDemob.last).to have_attributes(req_number_raw: 'O-999', resource_id: nil)
    end
  end

  describe 'matching' do
    it 'matches a subordinate roster entry' do
      roster = resource.rosters.create!(name: 'Sam Roe', position: 'FFT2', order_number: '12.3')
      expect(RemoteDemob.match(incident, 'E-12.3')).to eq([resource, roster])
    end
  end

  describe 'demob queue and DMB' do
    before { login_user }

    let!(:rd) do
      incident.remote_demobs.create!(
        req_number_raw: 'E-12', resource: resource, name: 'Pat Lee', phone: '907-555-0199',
        travel_method: 'Rental', travel_start_date: Date.new(2026, 11, 6), travel_start_time: '0830',
        destination: 'Palmer, AK', ron: false, arrival_date: Date.new(2026, 11, 6),
        arrival_time: '1230', submitted_at: Time.current
      )
    end

    it 'links to the queue from the Plans page with a pending count' do
      get incident_planning_path(incident)
      expect(response.body).to include('Resource Demobs', '1 pending', incident_remote_demobs_path(incident))
    end

    it 'lists pending submissions with a DMB button' do
      get incident_remote_demobs_path(incident)
      expect(response.body).to include('Pat Lee', 'Palmer, AK', "remote_demob_id=#{rd.id}",
                                        remote_demob_url(token))
    end

    it 'fills the ICS-221 and marks the submission applied on save' do
      demob = resource.demob
      get incident_resource_demob_path(incident, resource, demob, remote_demob_id: rd.id)
      expect(response.body).to include('value="Palmer, AK"', 'value="Rental"', 'value="0830"',
                                        'value="907-555-0199"')

      patch demob_path(demob), params: { remote_demob_id: rd.id,
                                         demob: { destination: 'Palmer, AK', edt: '0830' } }
      expect(rd.reload).to have_attributes(status: 'applied', demob: demob)
    end

    it 'downloads QR codes for the demob and check-in links' do
      [qr_code_incident_remote_demobs_path(incident), qr_code_incident_remote_checkins_path(incident)].each do |path|
        get path
        expect(response.media_type).to eq('image/png')
        expect(response.headers['Content-Disposition']).to include('attachment', '-qr.png')
        expect(response.body.b).to start_with("\x89PNG".b)
      end
    end

    it 'dismisses a submission' do
      post dismiss_incident_remote_demob_path(incident, rd)
      expect(response).to redirect_to(incident_remote_demobs_path(incident))
      expect(rd.reload).to be_dismissed
    end
  end
end
