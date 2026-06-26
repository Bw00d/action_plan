class BoardsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  def show
    @columns = build_columns(@incident)
    @unassigned_resources = @incident.resources.unassigned.assigned.order(:category, :order_number)
  end

  def move
    resource = @incident.resources.find_by(id: params[:resource_id])
    return head :not_found unless resource

    target_org_unit = if params[:org_unit_id].present?
                       @incident.org_units.find_by(id: params[:org_unit_id])
                     end
    return head :unprocessable_entity if params[:org_unit_id].present? && target_org_unit.nil?

    apply_move(resource, target_org_unit, params[:position].to_i)
    head :no_content
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def apply_move(resource, target_org_unit, position)
    assignment = resource.org_unit_assignment

    if target_org_unit.nil?
      assignment&.destroy
      return
    end

    if assignment.nil?
      OrgUnitAssignment.create!(resource: resource, org_unit: target_org_unit).tap do |a|
        a.insert_at(position) if position.positive?
      end
    else
      assignment.update!(org_unit: target_org_unit)
      assignment.insert_at(position) if position.positive?
    end
  end

  def build_columns(incident)
    columns = []
    incident.org_units.roots.includes(:children).order(:kind, :position).each do |root|
      walk(root, columns)
    end
    columns
  end

  def walk(node, columns)
    columns << node
    node.children.order(:position).each { |child| walk(child, columns) }
  end
end
