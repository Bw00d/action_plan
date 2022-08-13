class PlansController < ApplicationController
  before_action :set_plan, only: [:show, :edit, :update, :destroy]
 
    

  include SkipAuthorization
  skip_before_action :authenticate_user!

  # GET /plans
  # GET /plans.json
  def index
    @plan = Plan.new
    @incident = Incident.find(params[:incident_id])
    @plans = Plan.where(incident_id: @incident.id).order(date: :desc)
  end

  # GET /plans/1
  # GET /plans/1.json
  def show
    @new_plan = Plan.new
    @incident = Incident.find(params[:incident_id])
    @resources = @incident.resources.order(:category, :order_number)
    @resource = Resource.new
    @plan = Plan.find(params[:id])
    @plans = Plan.all.order(date: :desc)
    @objectives = @plan.objectives.order(order: :asc)
    @objective = Objective.new
    @activity = Activity.new
  end

  # GET /plans/new
  def new
    @incident = Incident.find(params[:incident_id])
    @plan = Plan.new
  end

  # GET /plans/1/edit
  def edit
  end

  # POST /plans
  # POST /plans.json
  def create
    @plan = Plan.create(plan_params)
    @incident = Incident.find(params[:incident_id])
    respond_to do |format|
      if @plan.save
        format.html { redirect_to incident_plan_path(@incident, @plan) }
        format.json { redirect_to incident_plan_path(@incident, @plan) }
      else
        format.html { render :new }
        format.json { render json: @plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /plans/1
  # PATCH/PUT /plans/1.json
  def update
    respond_to do |format|
      if @plan.update(plan_params)
        format.html { redirect_to @plan }
        format.json { respond_with_bip(@plan) }
      else
        format.html { render :edit }
        format.json { render json: @plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /plans/1
  # DELETE /plans/1.json
  def destroy
    @plan.destroy
    respond_to do |format|
      format.html { redirect_to plans_url, notice: 'Plan was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def cover
    @plan = Plan.find(params[:id])
    @incident = Incident.find(@plan.incident_id)
  end
  
  def incident_objectives
    @plan = Plan.find(params[:id])
    @incident = Incident.find(@plan.incident_id)
  end

  def incident_organization
    @plan = Plan.find(params[:id])
    @incident = Incident.find(@plan.incident_id)
    @team = Team.new
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_plan
      @plan = Plan.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def plan_params
      params.require(:plan).permit(:date, :user_id, :situation, :incident_id, :weather, 
                                   :general_safety, :prepared_by, :org_list, :assignment_list, 
                                   :comm_plan, :med_plan, :incident_map, :comm_plan, 
                                   :travel_plan, :date_prepare, :time_prepared, :ops_period,
                                   :approved_by)
    end
end
