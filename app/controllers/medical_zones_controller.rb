class MedicalZonesController < ApplicationController
  include SkipAuthorization

  # Nested create — the ?kind=division|camp query param decides which
  # bucket (section 6 vs section 7) the new row goes into.
  def create
    mp   = Plan.find(params[:plan_id]).medical_plan || Plan.find(params[:plan_id]).create_medical_plan!
    kind = %w[division camp].include?(params[:kind]) ? params[:kind] : 'division'
    next_pos = (mp.medical_zones.where(kind: kind).maximum(:position) || 0) + 1
    mp.medical_zones.create!(kind: kind, position: next_pos)
    redirect_back fallback_location: root_path
  end

  def update
    row = MedicalZone.find(params[:id])
    respond_to do |format|
      format.json do
        row.update(row_params)
        respond_with_bip(row)
      end
    end
  end

  def destroy
    row = MedicalZone.find(params[:id])
    row.destroy
    redirect_back fallback_location: root_path
  end

  private

  def row_params
    params.require(:medical_zone).permit(:name, :poc, :ems_responders, :equipment,
                                         :medical_channel, :eta_air, :eta_ground,
                                         :helispot, :helispot_lat, :helispot_long)
  end
end
