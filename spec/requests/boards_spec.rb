require 'rails_helper'

RSpec.describe 'Boards', type: :request do
  before { login_user }

  let(:incident) { create(:incident, owner: @current_user) }
  let(:operations) { create(:org_unit, :section, incident: incident, name: 'Operations') }
  let(:division_a) { create(:org_unit, :division, incident: incident, parent: operations, name: 'Div A') }
  let(:division_b) { create(:org_unit, :division, incident: incident, parent: operations, name: 'Div B') }
  let(:resource) { create(:resource, incident: incident) }

  describe 'GET /incidents/:id/board' do
    it 'renders the board page' do
      division_a # create the unit
      get incident_board_path(incident)
      expect(response).to have_http_status(200)
      expect(response.body).to include('Div A')
      expect(response.body).to include('Unassigned')
    end
  end

  describe 'PATCH /incidents/:id/board/move' do
    it 'creates an assignment when a card is dropped into a column' do
      expect {
        patch move_incident_board_path(incident),
              params: { resource_id: resource.id, org_unit_id: division_a.id, position: 1 }
      }.to change(OrgUnitAssignment, :count).by(1)
      expect(response).to have_http_status(:no_content)
      expect(resource.reload.org_unit).to eq(division_a)
    end

    it 'moves an existing assignment between columns' do
      create(:org_unit_assignment, org_unit: division_a, resource: resource)
      patch move_incident_board_path(incident),
            params: { resource_id: resource.id, org_unit_id: division_b.id, position: 1 }
      expect(response).to have_http_status(:no_content)
      expect(resource.reload.org_unit).to eq(division_b)
    end

    it 'removes the assignment when dropped onto Unassigned (org_unit_id blank)' do
      create(:org_unit_assignment, org_unit: division_a, resource: resource)
      expect {
        patch move_incident_board_path(incident),
              params: { resource_id: resource.id, org_unit_id: '', position: 1 }
      }.to change(OrgUnitAssignment, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'returns 404 if the resource does not belong to the incident' do
      other_resource = create(:resource, incident: create(:incident))
      patch move_incident_board_path(incident),
            params: { resource_id: other_resource.id, org_unit_id: division_a.id, position: 1 }
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 422 if the org_unit does not belong to the incident' do
      other_unit = create(:org_unit, :division,
                           incident: create(:incident),
                           parent: create(:org_unit, :section, incident: create(:incident)))
      patch move_incident_board_path(incident),
            params: { resource_id: resource.id, org_unit_id: other_unit.id, position: 1 }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
