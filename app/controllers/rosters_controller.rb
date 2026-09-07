class RostersController < ApplicationController
  include SkipAuthorization

  before_action :set_roster, only: [:promote, :demob_checkout]

  # POST /rosters/:id/promote
  def promote
    if @roster.promoted?
      redirect_back fallback_location: root_path, alert: "Already promoted."
      return
    end

    @roster.promote!
    redirect_back fallback_location: root_path, notice: "Promoted #{@roster.name} to its own T-card."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: root_path, alert: "Could not promote: #{e.message}"
  end

  # GET /rosters/:id/demob_checkout
  # Sends the user to the existing ICS-221 checkout page for this
  # roster's demob record. Lazy-creates the demob if needed (legacy
  # rosters won't have one yet). The checkout page reads demob.roster
  # and swaps in the subordinate's identity + toggles PRINT/SUBMIT.
  def demob_checkout
    incident = @roster.resource.incident
    demob    = @roster.demob_or_create
    redirect_to incident_resource_demob_path(incident, @roster.resource, demob)
  end

  private

  def set_roster
    @roster = Roster.find(params[:id])
  end
end
