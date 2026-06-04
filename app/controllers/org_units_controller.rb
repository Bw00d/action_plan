class OrgUnitsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  def create
    parent = @incident.org_units.find_by(id: params.dig(:org_unit, :parent_id))
    unless parent
      redirect_to incident_board_path(@incident),
                  flash: { error: 'Parent unit not found for this incident.' }
      return
    end

    unit = @incident.org_units.new(org_unit_params.merge(parent: parent))

    if unit.save
      redirect_to incident_board_path(@incident),
                  notice: "Added #{unit.kind.capitalize} \"#{unit.name}\"."
    else
      redirect_to incident_board_path(@incident),
                  flash: { error: unit.errors.full_messages.to_sentence }
    end
  end

  DELETABLE_KINDS = %w[branch division group].freeze

  def destroy
    unit = @incident.org_units.find_by(id: params[:id])
    unless unit
      redirect_to incident_board_path(@incident),
                  flash: { error: 'That unit does not exist on this incident.' }
      return
    end

    unless DELETABLE_KINDS.include?(unit.kind)
      redirect_to incident_board_path(@incident),
                  flash: { error: "#{unit.kind.capitalize} units can't be deleted." }
      return
    end

    name = unit.name
    kind = unit.kind
    unit.destroy
    redirect_to incident_board_path(@incident),
                notice: "Deleted #{kind} \"#{name}\". Any resources on it moved to Unassigned."
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def org_unit_params
    params.require(:org_unit).permit(:kind, :name, :designator)
  end
end
