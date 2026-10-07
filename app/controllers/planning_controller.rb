class PlanningController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  # GET /incidents/:incident_id/planning
  def show
    @result = session_result   # survives the roundtrip from the POST below
  end

  # POST /incidents/:incident_id/planning/reconcile_iroc
  # Body: iroc_csv (file upload)
  def reconcile_iroc
    if params[:iroc_csv].blank?
      redirect_to incident_planning_path(@incident),
                  alert: 'Pick an IROC CSV to upload first.'
      return
    end

    csv_io  = params[:iroc_csv].tempfile
    @result = IrocReconciler.new(csv_io).reconcile(@incident)

    # Store the result in flash so a subsequent GET can re-render — PRG
    # pattern. Flash can carry structs if we serialize to plain hashes.
    flash[:iroc_result] = serialize_result(@result)
    redirect_to incident_planning_path(@incident)
  rescue => e
    Rails.logger.error "IROC reconcile failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to incident_planning_path(@incident),
                alert: "Couldn't parse that CSV: #{e.message}"
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def session_result
    data = flash[:iroc_result]
    return nil unless data
    IrocReconciler::Result.new(
      missing:            Array(data['missing']).map { |m| IrocReconciler::MissingRow.new(m.symbolize_keys) },
      matched_count:      data['matched_count'].to_i,
      skipped_bad_prefix: data['skipped_bad_prefix'].to_i,
      skipped_bad_status: data['skipped_bad_status'].to_i,
      errors:             Array(data['errors'])
    )
  end

  def serialize_result(result)
    {
      'missing'            => result.missing.map(&:to_h).map(&:stringify_keys),
      'matched_count'      => result.matched_count,
      'skipped_bad_prefix' => result.skipped_bad_prefix,
      'skipped_bad_status' => result.skipped_bad_status,
      'errors'             => result.errors
    }
  end
end
