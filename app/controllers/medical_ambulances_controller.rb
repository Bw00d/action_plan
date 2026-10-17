class MedicalAmbulancesController < ApplicationController
  include SkipAuthorization

  def create
    # URL is /incidents/:incident_id/plans/:plan_id/medical_plan/ambulances
    # (singular `resource :medical_plan`), so the parent medical_plan
    # is looked up via the plan — not via a :medical_plan_id param
    # (which doesn't exist on a singular nested resource).
    mp = Plan.find(params[:plan_id]).medical_plan || Plan.find(params[:plan_id]).create_medical_plan!
    next_pos = (mp.medical_ambulances.maximum(:position) || 0) + 1
    mp.medical_ambulances.create!(position: next_pos)
    redirect_back fallback_location: root_path
  end

  def update
    row = MedicalAmbulance.find(params[:id])
    respond_to do |format|
      format.json do
        row.update(row_params)
        respond_with_bip(row)
      end
    end
  end

  def destroy
    row = MedicalAmbulance.find(params[:id])
    row.destroy
    redirect_back fallback_location: root_path
  end

  private

  def row_params
    params.require(:medical_ambulance).permit(:name, :address, :phone_ems_freq, :als)
  end
end
