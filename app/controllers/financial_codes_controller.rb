class FinancialCodesController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :set_code, only: [:update, :destroy]

  # POST /incidents/:incident_id/financial_codes
  def create
    next_position = (@incident.financial_codes.maximum(:position) || 0) + 1
    @code = @incident.financial_codes.new(financial_code_params.merge(position: next_position))
    respond_to do |format|
      if @code.save
        format.html { redirect_back(fallback_location: incident_path(@incident), notice: "Added #{@code.agency} code.") }
      else
        format.html { redirect_back(fallback_location: incident_path(@incident), alert: @code.errors.full_messages.to_sentence) }
      end
    end
  end

  # PATCH /incidents/:incident_id/financial_codes/:id  (used by best_in_place)
  def update
    respond_to do |format|
      if @code.update(financial_code_params)
        format.html { redirect_back(fallback_location: incident_path(@incident)) }
        format.json { respond_with_bip(@code) }
      else
        format.html { redirect_back(fallback_location: incident_path(@incident), alert: @code.errors.full_messages.to_sentence) }
        format.json { respond_with_bip(@code) }
      end
    end
  end

  # DELETE /incidents/:incident_id/financial_codes/:id
  def destroy
    agency = @code.agency
    @code.destroy
    redirect_back(fallback_location: incident_path(@incident), notice: "Removed #{agency} code.")
  end

  # POST /incidents/:incident_id/financial_codes/apply_irwin
  # Payload: { codes: { "BLM" => "SRP8", "USFS" => "PN SRP8 (1542)" } }
  # Upserts each agency/code pair; leaves any other agencies (state, compact,
  # etc.) untouched.
  def apply_irwin
    pairs = params[:codes].to_unsafe_h rescue {}
    upserted = 0
    pairs.each do |agency, code|
      next if agency.blank? || code.blank?
      row = @incident.financial_codes.find_or_initialize_by(agency: agency.to_s.strip.upcase)
      row.code = code.to_s.strip
      row.position ||= (@incident.financial_codes.maximum(:position) || 0) + 1
      row.save!
      upserted += 1
    end
    render json: { updated: upserted }
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def set_code
    @code = @incident.financial_codes.find(params[:id])
  end

  def financial_code_params
    params.require(:financial_code).permit(:agency, :code, :notes)
  end
end
