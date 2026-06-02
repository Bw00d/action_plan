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

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def org_unit_params
    params.require(:org_unit).permit(:kind, :name, :designator)
  end
end
