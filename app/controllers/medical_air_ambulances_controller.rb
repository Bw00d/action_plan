class MedicalAirAmbulancesController < ApplicationController
  include SkipAuthorization

  def create
    mp = Plan.find(params[:plan_id]).medical_plan || Plan.find(params[:plan_id]).create_medical_plan!
    next_pos = (mp.medical_air_ambulances.maximum(:position) || 0) + 1
    mp.medical_air_ambulances.create!(position: next_pos)
    redirect_back fallback_location: root_path
  end

  def update
    row = MedicalAirAmbulance.find(params[:id])
    respond_to do |format|
      format.json do
        row.update(row_params)
        respond_with_bip(row)
      end
    end
  end

  def destroy
    row = MedicalAirAmbulance.find(params[:id])
    row.destroy
    redirect_back fallback_location: root_path
  end

  private

  def row_params
    params.require(:medical_air_ambulance).permit(:name, :phone, :aircraft_capability)
  end
end
