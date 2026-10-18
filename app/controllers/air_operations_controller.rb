class AirOperationsController < ApplicationController
  include SkipAuthorization

  # GET /incidents/:incident_id/plans/:plan_id/air_operation
  # Lazy-create the air_operation on first visit — same pattern as
  # medical_plan — so the ICS 220 sheet is ready to edit on open.
  def show
    @incident      = Incident.find(params[:incident_id])
    @plan          = @incident.plans.find(params[:plan_id])
    @air_operation = @plan.air_operation || @plan.create_air_operation!
    # The 205's commo_items feed the section-13 "pick from 205" picker.
    # Skip rows that have no identifying text so the dropdown shows
    # only usable channels. Order mirrors the printed 205.
    @commo_items = (@plan.commo_plan&.commo_items&.order(:position, :id) || [])
                     .reject { |ci| ci.channel_name.blank? && ci.function.blank? && ci.rx_freq.blank? }
  end

  # PATCH /air_operations/:id — top-level best_in_place endpoint for
  # the parent record's many inline-editable fields.
  def update
    @air_operation = AirOperation.find(params[:id])
    respond_to do |format|
      @air_operation.update(air_operation_params)
      format.json { respond_with_bip(@air_operation) }
    end
  end

  private

  # Permit every editable column on the AirOperation parent. The lists
  # mirror the fixed-row sections (13 & 14) and the sections 9-12 + 15
  # free-text blocks.
  def air_operation_params
    allowed = %i[
      date_prepared time_prepared prepared_by
      sunrise sunset pumpkin_time shutdown
      general_remarks
      helibase_name helibase_lat helibase_long
      tfr_notam tfr_altitude tfr_frequency tfr_hours
      medevac_faa medevac_phone medevac_location medevac_capabilities
      shorthaul_faa shorthaul_phone shorthaul_location shorthaul_capabilities
      hoist_faa hoist_phone hoist_location hoist_capabilities
      request_through equipment_supplies
    ]
    AirOperation::FREQUENCY_ROWS.each do |r|
      allowed += %i[rx tone tx tx_tone mode].map { |c| "freq_#{r[:key]}_#{c}".to_sym }
      allowed << "freq_#{r[:key]}_label".to_sym
    end
    AirOperation::POSITION_ROWS.each do |r|
      allowed += %i[label name phone].map { |c| "pos_#{r[:key]}_#{c}".to_sym }
    end
    params.require(:air_operation).permit(*allowed)
  end
end
