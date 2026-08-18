class AssignmentsController < ApplicationController
  before_action :set_assignment, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  # GET /assignments
  # GET /assignments.json
  def index
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @assignments = @plan.assignments
  end

  # GET /assignments/1
  # GET /assignments/1.json
  def show
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @assignments = @plan.assignments
    # @freq = Freq.new
  end

  def assignment_to_pdf
    @assignment = Assignment.find(params[:id])
    @plan = Plan.find(@assignment.plan_id)
    @incident = Incident.find(@plan.incident_id)
    @assignments = @plan.assignments
    
    respond_to do |format|
      format.pdf do
        # Set up for absolute URLs in PDF
        Rails.application.routes.default_url_options[:host] = request.host_with_port
        Rails.application.routes.default_url_options[:protocol] = request.protocol
        
        html = render_to_string(
          template: 'assignments/assignment_to_pdf.pdf.erb',
          layout: 'layouts/pdf.html.erb',
          locals: { 
            assignment: @assignment, 
            plan: @plan, 
            incident: @incident,
            assignments: @assignments 
          }
        )
        
        # Explicit margins so puppeteer doesn't fall back to its 1cm
        # defaults, which shrink the printable area below what the
        # server-paginated .wf-page blocks assume.
        pdf = Grover.new(
          html,
          display_url: request.base_url,
          format: 'Letter',
          margin: { top: '0.25in', right: '0.4in', bottom: '0.25in', left: '0.4in' },
          prefer_css_page_size: false
        ).to_pdf

        disposition = params[:download].present? ? 'attachment' : 'inline'
        send_data pdf, filename: "assignment_#{@assignment.id}.pdf", type: 'application/pdf', disposition: disposition
      end
    end
  end

  # GET /assignments/new
  def new
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @assignment = Assignment.new
  end

  # GET /assignments/1/edit
  def edit
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
  end

  # POST /assignments
  # POST /assignments.json
  def create
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @assignment = Assignment.new(assignment_params)

    respond_to do |format|
      if @assignment.save
        format.html { redirect_to incident_plan_assignments_path(@incident, @plan) }
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
        format.html { redirect_back(fallback_location: root_path) }
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
    @plan = Plan.find(@assignment.plan_id)
    @incident = Incident.find(@plan.incident_id)
    @assignment.destroy
    respond_to do |format|
      format.html { redirect_to incident_plan_assignments_path(@incident, @plan) }
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
      params.require(:assignment).permit(:designator, :org_unit_id, :control_operations, :special_instructions,
                                         :plan_id, :ops_period, :ops_period_from, :ops_period_to,
                                         :operations_chief_id, :division_group_supervisor_id,
                                         :branch_director_id, :air_attack_supervisor_id,
                                         :prepared_date, :prepared_time,
                                         commo_item_ids: [], resource_ids: [],
                                         ops_personnel_ids: [])
    end
end
