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

  describe 'DELETE /incidents/:incident_id/org_units/:id' do
    let(:division) { create(:org_unit, :division, incident: incident, parent: operations, name: 'Div A', designator: 'A') }

    it 'deletes a division and unassigns its resources' do
      resource = create(:resource, incident: incident)
      create(:org_unit_assignment, org_unit: division, resource: resource)

      expect {
        delete incident_org_unit_path(incident, division)
      }.to change(OrgUnit, :count).by(-1)
       .and change(OrgUnitAssignment, :count).by(-1)

      expect(response).to redirect_to(incident_board_path(incident))
      expect(Resource.unassigned).to include(resource)
    end

    it 'refuses to delete a Section' do
      ops_id = operations.id
      expect {
        delete incident_org_unit_path(incident, operations)
      }.not_to change(OrgUnit, :count)
      expect(flash[:error]).to match(/can't be deleted/)
      expect(OrgUnit.exists?(ops_id)).to be true
    end

    it 'cascades when deleting a Branch with child Divisions' do
      branch = create(:org_unit, :branch, incident: incident, parent: operations, name: 'Branch I')
      child_div = create(:org_unit, :division, incident: incident, parent: branch, name: 'Div B')
      resource = create(:resource, incident: incident)
      create(:org_unit_assignment, org_unit: child_div, resource: resource)

      expect {
        delete incident_org_unit_path(incident, branch)
      }.to change(OrgUnit, :count).by(-2)
       .and change(OrgUnitAssignment, :count).by(-1)

      expect(Resource.unassigned).to include(resource)
    end

    it 'nullifies references on Assignment and PlanAssignmentSnapshot rather than blocking delete' do
      plan = create(:plan, incident: incident)
      assignment = create(:assignment, plan: plan, org_unit: division, designator: 'A')
      resource = create(:resource, incident: incident)
      create(:org_unit_assignment, org_unit: division, resource: resource)
      Plans::Publish.call(plan)
      snapshot = plan.assignment_snapshots.find_by(org_unit_id: division.id)
      expect(snapshot).not_to be_nil

      expect {
        delete incident_org_unit_path(incident, division)
      }.to change(OrgUnit, :count).by(-1)

      expect(assignment.reload.org_unit_id).to be_nil
      expect(snapshot.reload.org_unit_id).to be_nil
      expect(snapshot.designator_at_publish).to eq('A')
    end

    it 'refuses to delete a unit from another incident' do
      other_incident = create(:incident)
      foreign_ops = create(:org_unit, :section, incident: other_incident, name: 'Operations')
      foreign_div = create(:org_unit, :division, incident: other_incident, parent: foreign_ops, name: 'Div X')

      expect {
        delete incident_org_unit_path(incident, foreign_div)
      }.not_to change(OrgUnit, :count)
      expect(flash[:error]).to match(/does not exist on this incident/)
    end
  end
end
