class PlanningController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  # GET /incidents/:incident_id/planning
  def show
    @result = nil
  end

  # POST /incidents/:incident_id/planning/reconcile_iroc
  # Body: iroc_csv (file upload)
  #
  # Renders the Planning dashboard directly with the result in @result
  # instead of PRG-ing through flash. A long missing-resources list is
  # too big for the 4KB flash cookie (ActionDispatch::Cookies::
  # CookieOverflow), and there's no real reason to redirect here —
  # the user won't bookmark or refresh this response.
  def reconcile_iroc
    if params[:iroc_csv].blank?
      redirect_to incident_planning_path(@incident),
                  alert: 'Pick an IROC CSV to upload first.'
      return
    end

    csv_io  = params[:iroc_csv].tempfile
    @result = IrocReconciler.new(csv_io).reconcile(@incident)
    render :show
  rescue => e
    Rails.logger.error "IROC reconcile failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to incident_planning_path(@incident),
                alert: "Couldn't parse that CSV: #{e.message}"
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end
end
