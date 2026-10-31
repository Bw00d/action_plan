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

  describe 'R&R board' do
    let(:rnr_board) { incident.org_units.kind_rnr.first }
    let(:today) { Date.current }

    before { create(:org_unit_assignment, org_unit: division_a, resource: resource) }

    def schedule_rnr(from, to)
      resource.resource_events.create!(kind: :rnr, fwd: from, lwd: to)
    end

    def drag_to(unit)
      patch move_incident_board_path(incident),
            params: { resource_id: resource.id, org_unit_id: unit.id, position: 1 }
    end

    it 'is created with the incident' do
      expect(incident.org_units.kind_rnr.pluck(:name)).to eq(['R&R'])
    end

    it 'shows the card on the R&R board once R&R starts, off the tally' do
      schedule_rnr(today, today + 2)
      get incident_board_path(incident)

      expect(response.body).to include(%(data-resource-id="#{resource.id}"))
      expect(incident.tally_resources).not_to include(resource)
      expect(resource.reload.org_unit).to eq(division_a)
    end

    it 'leaves a card in its column until R&R starts' do
      schedule_rnr(today + 3, today + 5)

      expect(resource.rnr?).to be(false)
      expect(incident.tally_resources).to include(resource)
    end

    it 'returns the card to its column after R&R ends' do
      schedule_rnr(today - 3, today - 1)

      expect(resource.rnr?).to be(false)
      expect(division_a.resources.active).to include(resource)
    end

    it 'starts a scheduled R&R early when dragged to the board, keeping the planned dates' do
      event = schedule_rnr(today + 3, today + 5)
      drag_to(rnr_board)

      expect(response).to have_http_status(:no_content)
      expect(resource.reload.rnr?).to be(true)
      expect(incident.tally_resources).not_to include(resource)
      expect(event.reload).to have_attributes(fwd: today + 3, lwd: today + 5, actual_fwd: today)
      expect(resource.org_unit).to eq(division_a)
    end

    it 'refuses a drag to the board with no scheduled R&R' do
      drag_to(rnr_board)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Schedule R&R')
      expect(resource.reload.rnr?).to be(false)
    end

    it 'puts an early start back on schedule when dragged off the board' do
      event = schedule_rnr(today + 3, today + 5)
      drag_to(rnr_board)
      drag_to(division_b)

      expect(resource.reload.rnr?).to be(false)
      expect(event.reload.actual_fwd).to be_nil
      expect(event.actual_lwd).to be_nil
      expect(resource.org_unit).to eq(division_b)
    end

    it 'ends an R&R under way when dragged off the board' do
      event = schedule_rnr(today - 1, today + 2)
      drag_to(division_a)

      expect(resource.reload.rnr?).to be(false)
      expect(event.reload.actual_lwd).to eq(today)
    end

    it 'closes an early start when the 211 R&R box is unchecked' do
      schedule_rnr(today + 3, today + 5)
      drag_to(rnr_board)
      resource.reload.update!(r_and_r: true)
      resource.update!(r_and_r: false)

      expect(resource.reload.rnr?).to be(false)
    end
  end
end
