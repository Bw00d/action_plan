class MedicalPlansController < ApplicationController
  include SkipAuthorization

  # GET /incidents/:incident_id/plans/:plan_id/medical_plan
  # Lazy-create the medical_plan on first visit so the sheet is live
  # out of the gate (matches how commo_plan boots). Renders the full
  # 206 sheet with inline edits via best_in_place.
  def show
    @incident      = Incident.find(params[:incident_id])
    @plan          = @incident.plans.find(params[:plan_id])
    @medical_plan  = @plan.medical_plan || @plan.create_medical_plan!
  end

  # PATCH /medical_plans/:id — top-level route used by best_in_place
  # inline edits on the four header/footer fields.
  def update
    @medical_plan = MedicalPlan.find(params[:id])
    respond_to do |format|
      if @medical_plan.update(medical_plan_params)
        format.json { respond_with_bip(@medical_plan) }
      else
        format.json { respond_with_bip(@medical_plan) }
      end
    end
  end

  private

  def medical_plan_params
    params.require(:medical_plan).permit(:prepared_by, :prepared_at,
                                         :reviewed_by, :reviewed_at)
  end
end
