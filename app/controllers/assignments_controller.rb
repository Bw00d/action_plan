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
        #
        # display_header_footer + footer_template: the three-column
        # bottom bar (ICS marker, CUI banner, Page X of Y) is rendered
        # by Puppeteer on every physical page instead of being baked
        # into the .wf-page flex column. This stops the bar from being
        # clipped when a page's content runs tight, and keeps numbering
        # correct even when the last page's Control Ops text spills
        # onto a continuation sheet.
        # Puppeteer's footer-template runs in its own isolated context
        # and is picky — flex-end alignment plus a tight bottom margin
        # pushes text straight into the page-cut edge, so we align to
        # the top of the footer zone and pad left/right for the Grover
        # margins. Font size kept at 9pt (anything smaller gets
        # rendered noticeably faint by puppeteer's print engine).
        footer_template = <<~HTML
          <div style="font-size:9pt;font-family:Arial,sans-serif;font-weight:bold;color:#000;width:100%;padding:0.05in 0.4in 0;display:flex;justify-content:space-between;align-items:flex-start;line-height:1.2;">
            <span style="width:25%;text-align:left;">ICS 204 WF (08/25)</span>
            <span style="width:50%;text-align:center;">Controlled Unclassified Information//Basic</span>
            <span style="width:25%;text-align:right;">Page <span class="pageNumber"></span> of <span class="totalPages"></span></span>
          </div>
        HTML

        pdf = Grover.new(
          html,
          display_url: request.base_url,
          format: 'Letter',
          # Bottom margin generously sized so puppeteer has room to
          # paint the footer bar without any clipping from the physical
          # page edge.
          margin: { top: '0.25in', right: '0.4in', bottom: '0.6in', left: '0.4in' },
          prefer_css_page_size: false,
          display_header_footer: true,
          header_template: '<div></div>',
          footer_template: footer_template
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
                                         :slot_1_role, :slot_1_person, :slot_2_role, :slot_2_person,
                                         :slot_3_role, :slot_3_person, :slot_4_role, :slot_4_person,
                                         :prepared_date, :prepared_time,
                                         commo_item_ids: [], resource_ids: [],
                                         ops_personnel_ids: [])
    end
end
