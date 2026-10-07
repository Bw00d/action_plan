class BoardsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  def show
    @columns = build_columns(@incident)

    # Eager-load everything each _card partial reads so the board stops
    # firing 5-6 queries per card. For a 150-card board this takes the
    # view from ~1000 SQL hits down to a handful.
    #
    # - rosters         → effective_personnel / personnel_by_agency
    # - demob           → DMB button URL in the modal footer
    # - resource_events → scheduled-swap flag + activity feed count
    @board_includes = [:rosters, :demob, :resource_events, :org_unit_assignment]

    @unassigned_resources = @incident.resources.unassigned.active
                                     .includes(@board_includes)
                                     .order(:category, :order_number)

    # Preload per-column resource lists once (grouped by org_unit_id)
    # so the view can look up a column's cards without re-querying per
    # column.
    unit_ids = @columns.map(&:id)
    assignments_by_unit = OrgUnitAssignment
      .where(org_unit_id: unit_ids)
      .includes(resource: @board_includes)
      .order(:org_unit_id, :position)
      .group_by(&:org_unit_id)

    @resources_by_unit = assignments_by_unit.transform_values do |asgs|
      asgs.map(&:resource).select { |r| r && r.release_date.nil? && !r.r_and_r }
    end
    @resources_by_unit.default = []
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

  def create_spacer
    resource = @incident.resources.create!(spacer: true)
    render partial: 'card', locals: { resource: resource }
  end

  def destroy_spacer
    resource = @incident.resources.where(spacer: true).find_by(id: params[:id])
    return head :not_found unless resource

    resource.destroy!
    head :no_content
  end

  # GET /incidents/:incident_id/board/roster
  # Printable list of every resource on the T-card board, grouped by
  # column (org_unit). Spacers are hidden; the Unassigned bucket is
  # appended at the bottom. Rendered standalone so the user can hit
  # Cmd/Ctrl+P and get a clean list — Order Number + Name only.
  def roster
    @groups = []
    @incident.org_units.roots.includes(:children).order(:kind, :position).each do |root|
      walk_with_resources(root, @groups)
    end
    @unassigned_resources = @incident.resources.unassigned.active
                                     .where(spacer: false)
                                     .order(:category, :order_number)
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def walk_with_resources(node, groups)
    groups << { unit: node,
                resources: node.resources.active.where(spacer: false).order(:position) }
    node.children.order(:position).each { |child| walk_with_resources(child, groups) }
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
