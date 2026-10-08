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

  # PATCH /incidents/:incident_id/board/reorder_columns
  # Body: { org_unit_ids: [12, 7, 15, ...] }  — the DOM-order list the
  # user ended up with after dragging columns around.
  #
  # Columns live in a tree (section → branch → division/group) and
  # `position` is scoped per parent via acts_as_list. We can't just
  # reparent on drop, but we CAN reassign position within each parent
  # based on the user's new order. Cross-parent drags are silent no-ops.
  def reorder_columns
    ids = Array(params[:org_unit_ids]).map(&:to_i)
    units_by_id = @incident.org_units.where(id: ids).index_by(&:id)
    # Group the dragged order by parent_id, preserving sequence.
    ordered_by_parent = Hash.new { |h, k| h[k] = [] }
    ids.each do |id|
      unit = units_by_id[id]
      next unless unit
      ordered_by_parent[unit.parent_id] << unit
    end
    # acts_as_list#insert_at renumbers siblings cleanly within each parent.
    ordered_by_parent.each_value do |siblings|
      siblings.each_with_index do |unit, idx|
        unit.insert_at(idx + 1) if unit.position != idx + 1
      end
    end
    head :ok
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
