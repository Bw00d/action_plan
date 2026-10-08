class RostersController < ApplicationController
  include SkipAuthorization

  before_action :set_roster, only: [:update, :destroy, :promote, :demob_checkout]

  # POST /resources/:resource_id/rosters
  # Inline add from the T-card roster block. Minimal fields — Name is
  # required; agency defaults to the parent via Roster's
  # default_agency_from_resource callback; order_number auto-fills to
  # the next sequential child when blank. Responds with the re-rendered
  # roster partial so the T-card modal can swap it in-place without a
  # page reload.
  def create
    resource = Resource.find(params[:resource_id])
    roster   = resource.rosters.new(roster_create_params)
    roster.order_number = next_child_order_number(resource) if roster.order_number.blank?

    if roster.save
      render partial: 'boards/roster_list', formats: [:html], locals: { resource: resource }
    else
      render json: { errors: roster.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /rosters/:id — inline best_in_place edits. Right now only
  # `status` (C / F) is exposed; other roster fields are edited
  # elsewhere or set by the import flow.
  def update
    respond_to do |format|
      if @roster.update(roster_params)
        format.html { redirect_back fallback_location: root_path }
        format.json { respond_with_bip(@roster) }
      else
        format.html { redirect_back fallback_location: root_path, alert: @roster.errors.full_messages.to_sentence }
        format.json { respond_with_bip(@roster) }
      end
    end
  end

  # DELETE /rosters/:id — remove a subordinate from the roster entirely.
  # Cascades to the roster's own demob record (Roster has_one :demob
  # with dependent: :destroy) and any demob_notifications tied to this
  # roster row.
  def destroy
    name = @roster.name.presence || @roster.full_order_number
    @roster.destroy
    redirect_back fallback_location: root_path, notice: "Deleted #{name} from the roster."
  rescue => e
    redirect_back fallback_location: root_path, alert: "Could not delete: #{e.message}"
  end

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

  def roster_params
    params.require(:roster).permit(:status)
  end

  def roster_create_params
    params.require(:roster).permit(:name, :position, :agency, :order_number, :phone, :status)
  end

  # Figure out the next sequential child order_number for a new roster
  # on this parent resource. Walks existing rosters, picks the trailing
  # integer from each (either "131.5" or "5" style — Roster
  # #full_order_number handles both). New number is max + 1, or 1 if
  # the parent has no rosters yet.
  def next_child_order_number(resource)
    existing = resource.rosters.map do |r|
      s = r.order_number.to_s
      s.include?('.') ? s.split('.').last.to_i : s.to_i
    end
    (existing.max || 0) + 1
  end
end
