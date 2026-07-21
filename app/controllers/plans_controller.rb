class PlansController < ApplicationController
  before_action :set_plan, only: [:show, :edit, :update, :destroy, :publish, :unpublish]
 
    

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
    @incident = Incident.find(@plan.incident_id)
    @plan.destroy
    respond_to do |format|
      format.html { redirect_to incident_plans_path(@incident) }
      format.json { head :no_content }
    end
  end

  def publish
    Plans::Publish.call(@plan)
    redirect_back fallback_location: incident_plan_path(@plan.incident_id, @plan),
                  notice: 'IAP published. The 204s are now locked to this ops period.'
  end

  def unpublish
    Plans::Unpublish.call(@plan)
    redirect_back fallback_location: incident_plan_path(@plan.incident_id, @plan),
                  notice: 'IAP returned to draft. 204s now reflect the live board again.'
  end

  def cover
    @plan = Plan.find(params[:id])
    @incident = Incident.find(@plan.incident_id)
    @cover = @plan.cover
    @block = Block.new
    if @cover
      @blocks = @cover.blocks.order(id: :asc)
    end
  end


  
  def incident_objectives
    @plan = Plan.find(params[:id])
    @incident = Incident.find(@plan.incident_id)
    @objective = Objective.new
    @attachments = @plan.attachments.order(id: :asc)
    @first_attachments = @attachments[0..2]
    @second_attachments = @attachments[3..5]
    @third_attachments = @attachments[6..8]
    @fourth_attachments = @attachments[9..11]
  end

  def objectives_to_pdf
    @plan = Plan.find(params[:id])
    @incident = Incident.find(@plan.incident_id)
    @attachments = @plan.attachments.order(:id)
    @first_attachments = @attachments[0..2]
    @second_attachments = @attachments[3..5]
    @third_attachments = @attachments[6..8]
    @fourth_attachments = @attachments[9..11]
    
    respond_to do |format|
      format.pdf do
        # Set up for absolute URLs in PDF
        Rails.application.routes.default_url_options[:host] = request.host_with_port
        Rails.application.routes.default_url_options[:protocol] = request.protocol
        
        html = render_to_string(
          template: 'plans/objectives_to_pdf.pdf.erb',
          layout: 'layouts/pdf.html.erb',
          locals: { 
            plan: @plan, 
            incident: @incident,
            attachments: @attachments,
            first_attachments: @first_attachments,
            second_attachments: @second_attachments,
            third_attachments: @third_attachments,
            fourth_attachments: @fourth_attachments
          }
        )
        
        pdf = Grover.new(html, display_url: request.base_url).to_pdf
        
        send_data pdf, filename: "objectives_plan_#{@plan.id}.pdf", type: 'application/pdf', disposition: 'inline'
      end
    end
  end


  def incident_organization
    @plan = Plan.find(params[:id])
    @incident = Incident.find(@plan.incident_id)
    @team = Team.new
  end

  def organization_to_pdf
    @plan = Plan.find(params[:id])
    @incident = Incident.find(@plan.incident_id)
    @team = Team.new
    
    respond_to do |format|
      format.pdf do
        # Set up for absolute URLs in PDF
        Rails.application.routes.default_url_options[:host] = request.host_with_port
        Rails.application.routes.default_url_options[:protocol] = request.protocol
        
        html = render_to_string(
          template: 'plans/organization_to_pdf.pdf.erb',
          layout: 'layouts/pdf.html.erb',
          locals: { plan: @plan, incident: @incident, team: @team }
        )

        # Fit the 203 on a single Letter page with even margins. print_background
        # keeps the header-row grey; prefer_css_page_size lets the layout's
        # @page rule (also letter) take precedence if it disagrees.
        pdf = Grover.new(html,
          display_url:            request.base_url,
          format:                 'Letter',
          margin:                 { top: '0.4in', right: '0.4in', bottom: '0.4in', left: '0.4in' },
          print_background:       true,
          prefer_css_page_size:   true,
          display_header_footer:  false  # kill Chrome's default header/footer text
        ).to_pdf

        send_data pdf, filename: "organization_plan_#{@plan.id}.pdf", type: 'application/pdf', disposition: 'inline'
      end
    end
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
