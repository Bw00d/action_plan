require 'rails_helper'

RSpec.describe 'OrgUnits', type: :request do
  before { login_user }

  let(:incident) { create(:incident, owner: @current_user) }
  let(:operations) { create(:org_unit, :section, incident: incident, name: 'Operations') }

  describe 'POST /incidents/:incident_id/org_units' do
    it 'creates a division under Operations' do
      parent_id = operations.id
      expect {
        post incident_org_units_path(incident),
             params: { org_unit: { kind: 'division', name: 'Div A', designator: 'A', parent_id: parent_id } }
      }.to change(OrgUnit, :count).by(1)
      expect(response).to redirect_to(incident_board_path(incident))

      unit = OrgUnit.find_by(name: 'Div A')
      expect(unit.kind).to eq('division')
      expect(unit.parent).to eq(operations)
    end

    it 'creates a branch under a section' do
      post incident_org_units_path(incident),
           params: { org_unit: { kind: 'branch', name: 'Branch I', parent_id: operations.id } }
      expect(OrgUnit.find_by(name: 'Branch I').kind).to eq('branch')
    end

    it 'flashes an error when the kind/parent combo is invalid' do
      division = create(:org_unit, :division, incident: incident, parent: operations, name: 'Div A')
      expect {
        post incident_org_units_path(incident),
             params: { org_unit: { kind: 'branch', name: 'Bad', parent_id: division.id } }
      }.not_to change(OrgUnit, :count)
      expect(response).to redirect_to(incident_board_path(incident))
      follow_redirect!
      expect(flash[:error]).to be_present
    end

    it 'rejects a parent from another incident' do
      other_incident = create(:incident)
      other_ops = create(:org_unit, :section, incident: other_incident, name: 'Operations')
      expect {
        post incident_org_units_path(incident),
             params: { org_unit: { kind: 'division', name: 'Div A', parent_id: other_ops.id } }
      }.not_to change(OrgUnit, :count)
      expect(flash[:error]).to match(/Parent unit not found/)
    end
  end
end
