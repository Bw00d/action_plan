class AssignmentsController < ApplicationController
  before_action :set_assignment, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  skip_before_action :authenticate_user!

  # GET /assignments
  # GET /assignments.json
  def index
    @plan = Plan.find(params[:plan_id])
    @assignments = Assignment.all
  end

  # GET /assignments/1
  # GET /assignments/1.json
  def show
    @plan = Plan.find(params[:plan_id])
  end

  # GET /assignments/new
  def new
    @plan = Plan.find(params[:plan_id])
    @assignment = Assignment.new
  end

  # GET /assignments/1/edit
  def edit
    @plan = Plan.find(params[:plan_id])
  end

  # POST /assignments
  # POST /assignments.json
  def create
    @plan = Plan.find(params[:plan_id])
    @assignment = Assignment.new(assignment_params)

    respond_to do |format|
      if @assignment.save
        format.html { redirect_to plan_assignments_path(@plan, @assignment) }
        format.json { render :show, status: :created, location: @assignment }
      else
        format.html { render :new }
        format.json { render json: @assignment.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /assignments/1
  # PATCH/PUT /assignments/1.json
  def update
    respond_to do |format|
      if @assignment.update_attributes(assignment_params)
        format.html { redirect_to :back }
        format.json { respond_with_bip(@assignment) }
      else
        format.html { render :action => "edit" }
        format.json { respond_with_bip(@assignment) }
      end
    end
  end


  # DELETE /assignments/1
  # DELETE /assignments/1.json
  def destroy
    @assignment.destroy
    respond_to do |format|
      format.html { redirect_to assignments_url, notice: 'Assignment was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_assignment
      @assignment = Assignment.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def assignment_params
      params.require(:assignment).permit(:designator, :control_operations, :special_instructions, :plan_id)
    end
end
