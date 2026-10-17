class MedicalHospitalsController < ApplicationController
  include SkipAuthorization

  def create
    mp = Plan.find(params[:plan_id]).medical_plan || Plan.find(params[:plan_id]).create_medical_plan!
    next_pos = (mp.medical_hospitals.maximum(:position) || 0) + 1
    mp.medical_hospitals.create!(position: next_pos)
    redirect_back fallback_location: root_path
  end

  def update
    row = MedicalHospital.find(params[:id])
    respond_to do |format|
      format.json do
        row.update(row_params)
        respond_with_bip(row)
      end
    end
  end

  def destroy
    row = MedicalHospital.find(params[:id])
    row.destroy
    redirect_back fallback_location: root_path
  end

  private

  def row_params
    params.require(:medical_hospital).permit(:name, :address, :lat, :long, :vhf,
                                             :travel_air, :travel_gnd, :phone,
                                             :helipad, :level_of_care)
  end
end
