class CommoPlansController < ApplicationController
  before_action :set_commo_plan, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  skip_before_action :authenticate_user!

  # GET /commo_plans
  # GET /commo_plans.json
  def index
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @commo_plan = CommoPlan.new
    respond_to do |format|
      if @plan.commo_plan
        format.html { redirect_to incident_plan_commo_plan_path(@incident, @plan, @plan.commo_plan)}
      else
        format.html { render 'index' }
      end
    end

  end

  # GET /commo_plans/1
  # GET /commo_plans/1.json
  def show
    @commo_plan = CommoPlan.find(params[:id])
    @plan = Plan.find(@commo_plan.plan_id)
    @incident = Incident.find(@plan.incident_id)
    @commo_item = CommoItem.new
  end

  # GET /commo_plans/new
  def new
    @plan = Plan.find(params[:plan_id])
    @commo_plan = CommoPlan.new(plan_id: @plan.id)
    respond_to do |format|
      if @commo_plan.save
        format.html { redirect_to @commo_plan }
        format.json { render :show, status: :created, location: @commo_plan }
      else
        format.html { render :new }
        format.json { render json: @commo_plan.errors, status: :unprocessable_entity }
      end
    end


  end

  # GET /commo_plans/1/edit
  def edit
  end

  # POST /commo_plans
  # POST /commo_plans.json
  def create
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @commo_plan = CommoPlan.new(commo_plan_params)
    
    respond_to do |format|
      if @commo_plan.save
        format.html { redirect_to incident_plan_commo_plan_path(@incident, @plan, @commo_plan) }
        format.json { render :show, status: :created, location: @commo_plan }
      else
        format.html { render :new }
        format.json { render json: @commo_plan.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /commo_plans/1
  # PATCH/PUT /commo_plans/1.json
  def update
    @commo_plan = CommoPlan.find params[:id]

    respond_to do |format|
      if @commo_plan.update_attributes(commo_plan_params)
        format.html { redirect_back(fallback_location: root_path) }
        format.json { respond_with_bip(@commo_plan) }
      else
        format.html { render :action => "show" }
        format.json { respond_with_bip(@commo_plan) }
      end
    end
  end

  # DELETE /commo_plans/1
  # DELETE /commo_plans/1.json
  def destroy
    @commo_plan.destroy
    respond_to do |format|
      format.html { redirect_to commo_plans_url, notice: 'Commo plan was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_commo_plan
      @commo_plan = CommoPlan.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def commo_plan_params
      params.require(:commo_plan).permit(:plan_id, :date_prepared, :ops_period, :date_signed, :special_instructions, :prepared_by)
    end
end
