class ResourcesController < ApplicationController
  before_action :set_resource, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  # GET /resources
  # GET /resources.json
  def index
    @incident = Incident.find(params[:incident_id])
    @resource = Resource.new
    @resources = @incident.resources.includes(:rosters).order(:category, :order_number)
    # Same list minus any resource parked in a Non-209 org_unit. Used by
    # the ICS-211, Glide Path, and Resource Tally tabs (see the partials);
    # the resource panels / edit forms still use @resources so users can
    # still manage Non-209 resources from the side panel.
    non_209_ids = @incident.non_209_resource_ids
    @tally_resources = non_209_ids.any? ? @resources.where.not(id: non_209_ids) : @resources
    @overhead  = @resources.overhead
    @equipment = @resources.equipment
    @crews     = @resources.crew
    @aircraft  = @resources.aircraft
  end

  # GET /resources/1
  # GET /resources/1.json
  def show
  end

  # GET /incidents/:incident_id/resources/tally_to_pdf.pdf
  # Renders the Resource Tally pivot as a landscape PDF via Grover.
  def tally_to_pdf
    @incident = Incident.find(params[:incident_id])

    Rails.application.routes.default_url_options[:host]     = request.host_with_port
    Rails.application.routes.default_url_options[:protocol] = request.protocol

    html = render_to_string(
      template: 'resources/tally_to_pdf.pdf.erb',
      layout:   'layouts/pdf.html.erb'
    )

    pdf = Grover.new(html,
      display_url:          request.base_url,
      format:               'Letter',
      landscape:            true,
      margin:               { top: '0.4in', right: '0.4in', bottom: '0.4in', left: '0.4in' },
      print_background:     true,
      prefer_css_page_size: true,
      display_header_footer: false
    ).to_pdf

    send_data pdf, filename: "resource_tally_#{@incident.id}.pdf",
                   type: 'application/pdf', disposition: 'inline'
  end

  # GET /resources/new
  def new
    @resource = Resource.new
  end

  # GET /resources/1/edit
  def edit
  end

  # POST /resources
  # POST /resources.json
  def create
    @resource = Resource.new(resource_params)

    respond_to do |format|
      if @resource.save
        format.html { redirect_to incident_plan_path(@incident, @plan) }
        format.js { }
        format.json { render :show, status: :created, location: @resource }
      else
        format.html { render :new }
        format.js   { render :create_error, status: :unprocessable_entity }
        format.json { render json: @resource.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /resources/1
  # PATCH/PUT /resources/1.json
  def update
    respond_to do |format|
      if @resource.update(resource_params)
        format.html { redirect_back(fallback_location: root_path) }
        format.json { respond_with_bip(@resource) }
        format.js {}
      else
        format.html { render :edit }
        format.json { respond_with_bip(@resource) }
        format.js {}

      end
    end
  end

  # POST /incidents/:incident_id/resources/import_isuite
  # Accepts an e-iSuite CSV export. If the import would create new rows or
  # change existing ones, renders the preview page so the operator can
  # pick which updates to apply. Otherwise applies immediately.
  def import_isuite
    @incident = Incident.find(params[:incident_id])
    if params[:isuite_csv].blank?
      redirect_to incident_resources_path(@incident), alert: "Choose an iSuite CSV to import."
      return
    end

    # Read the CSV as text so we can re-parse it on the apply step —
    # storing the raw bytes in Postgres survives dyno restarts and works
    # across multiple web processes (unlike Rails.cache's default store).
    csv_data = params[:isuite_csv].tempfile.read.force_encoding("UTF-8")
    rows     = IsuiteImporter.new(StringIO.new(csv_data)).parsed_rows
    @plan    = IsuiteImporter.new(nil).send(:build_plan, @incident, rows)

    has_changes = @plan.resource_changes.any? || @plan.roster_changes.any?
    has_new     = @plan.new_resources.any?   || @plan.new_rosters.any?

    if !has_changes && !has_new
      redirect_to incident_resources_path(@incident),
                  notice: "No new rows and no changes to apply (#{@plan.unchanged_count} rows already up to date)."
      return
    end

    staging = IsuiteImportStaging.stash(
      incident: @incident,
      user:     current_user,
      csv_data: csv_data
    )
    @import_token = staging.token
    render :import_isuite_preview
  end

  # POST /incidents/:incident_id/resources/apply_isuite_import
  # Body: import_token, resource_ids[] (checked), roster_ids[] (checked)
  def apply_isuite_import
    @incident = Incident.find(params[:incident_id])
    staging   = IsuiteImportStaging.find_active(params[:import_token])
    unless staging
      redirect_to incident_resources_path(@incident),
                  alert: "Import preview expired (>#{IsuiteImportStaging::TTL.inspect} old). Please upload the CSV again."
      return
    end

    rows = IsuiteImporter.new(StringIO.new(staging.csv_data)).parsed_rows
    result = IsuiteImporter.apply(
      @incident, rows,
      selected_resource_ids: Array(params[:resource_ids]),
      selected_roster_ids:   Array(params[:roster_ids])
    )
    staging.destroy

    parts = []
    parts << "Added #{result.resources_created} resource#{'s' if result.resources_created != 1}"           if result.resources_created.positive?
    parts << "#{result.rosters_created} roster entr#{result.rosters_created == 1 ? 'y' : 'ies'} added"     if result.rosters_created.positive?
    parts << "updated #{result.resources_updated} resource#{'s' if result.resources_updated != 1}"         if result.resources_updated.positive?
    parts << "updated #{result.rosters_updated} roster entr#{result.rosters_updated == 1 ? 'y' : 'ies'}"   if result.rosters_updated.positive?
    parts << "#{result.demobed_skipped} demobed"      if result.demobed_skipped.positive?
    parts << "#{result.service_skipped} service rows" if result.service_skipped.positive?
    notice = parts.any? ? (parts.join(", ") + ".") : "Nothing to do — no items were selected."
    notice += " Errors: #{result.errors.first(3).join(' | ')}#{'…' if result.errors.size > 3}" if result.errors.any?

    redirect_to incident_resources_path(@incident), notice: notice
  end

  # DELETE /resources/1
  # DELETE /resources/1.json
  def destroy
    @resource.destroy
    respond_to do |format|
      format.html { redirect_to incident_resources_path(@resource.incident) }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_resource
      @resource = Resource.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def resource_params
      params.require(:resource).permit(:name, :leader, :number_personnel, :position, :agency,
                                       :order_number, :lwd, :checkin_date, :incident_id, :category,
                                       :phone, :email, :comment, :fwd, :assignment_length, :release_date,
                                       :r_and_r, :jetport, :return_city, :return_state,
                                       :drop_off_pt_time, :pick_up_pt_time)
    end

end
