class ResourcesController < ApplicationController
  before_action :set_resource, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  # GET /resources
  # GET /resources.json
  def index
    @incident = Incident.find(params[:incident_id])
    @resource = Resource.new

    # Eager-load every association the 6 partials walk. Without this
    # each row fires fresh queries for its rosters / demob / events /
    # assignment — easily hundreds of queries per page on a busy
    # incident. Kept as a Relation (not .to_a) because downstream
    # partials chain scopes like .assigned, .on_rnr, .overhead onto it.
    base = @incident.resources
                    .includes(:rosters, :demob, :resource_events, :org_unit_assignment)
                    .order(:category, :order_number)
    @resources = base

    # Same list minus any resource parked in a Non-209 org_unit. Used by
    # the ICS-211, Glide Path, and Resource Tally tabs (see the partials);
    # the resource panels / edit forms still use @resources so users can
    # still manage Non-209 resources from the side panel.
    non_209_ids = @incident.non_209_resource_ids
    @tally_resources   = non_209_ids.any? ? base.where.not(id: non_209_ids) : base
    @non_209_resources = non_209_ids.any? ? base.where(id: non_209_ids) : Resource.none
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

  # GET /incidents/:incident_id/resources/tally_to_csv
  # Flat CSV of the Resource Tally pivot — opens cleanly in Excel /
  # Numbers / Google Sheets. First column is the agency; next column
  # labels the count type (resources vs personnel); remaining columns
  # mirror the on-screen tally (per-position + Overhead + Total +
  # Non-209 + Total Incident). The Total row from the on-screen footer
  # is appended at the bottom.
  def tally_to_csv
    require 'csv'
    @incident = Incident.find(params[:incident_id])
    pivot     = helpers.resource_tally_pivot(@incident)

    # Columns that only carry a personnel value (no per-row resource
    # count) — Overhead rolls up resources without position buckets,
    # and the three summaries are purely personnel sums.
    personnel_only_keys = %w[OVERHEAD TOTAL NON_209 TOTAL_INCIDENT].freeze

    csv = CSV.generate do |out|
      out << ['Agency', 'Count'] + pivot[:columns].map { |c| c[:label] }

      pivot[:agencies].each do |agency|
        cells = pivot[:rows][agency]
        %i[resources personnel].each do |kind|
          out << [agency, kind.to_s] +
                 pivot[:columns].map { |c|
                   next '' if kind == :resources && personnel_only_keys.include?(c[:key])
                   v = cells[c[:key]][kind]
                   v.to_i.zero? ? '' : v
                 }
        end
      end

      # Grand-total footer rows.
      %i[resources personnel].each do |kind|
        out << ['Total', kind.to_s] +
               pivot[:columns].map { |c|
                 next '' if kind == :resources && personnel_only_keys.include?(c[:key])
                 v = pivot[:totals][c[:key]][kind]
                 v.to_i.zero? ? '' : v
               }
      end
    end

    stamp    = Time.current.strftime('%Y%m%d_%H%M')
    filename = "resource_tally_#{@incident.id}_#{stamp}.csv"
    send_data csv, filename: filename, type: 'text/csv', disposition: 'attachment'
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
  #
  # Subordinate detection: if the entered order_number looks like a
  # subordinate (contains a dot — e.g. "131.2") AND a parent Resource
  # with the base number exists in the same incident+category, we create
  # a Roster on the parent instead of a fresh Resource. Matches the
  # inverse of Roster#promote! and mirrors how iSuite records subordinates
  # (parent "131" + child "2" → display "E-131.2").
  def create
    if (roster = maybe_build_subordinate_roster)
      respond_to do |format|
        if roster.save
          format.html { redirect_back fallback_location: incident_resources_path(roster.resource.incident),
                                      notice: "Added subordinate #{roster.full_order_number}." }
          format.js   { render :create_roster }
          format.json { render json: { ok: true, roster_id: roster.id } }
        else
          format.html { redirect_back fallback_location: incident_resources_path(roster.resource.incident),
                                      alert: roster.errors.full_messages.to_sentence }
          format.js   { render :create_error, status: :unprocessable_entity }
          format.json { render json: roster.errors, status: :unprocessable_entity }
        end
      end
      return
    end

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

  # If the submitted resource_params describe a subordinate (dotted order
  # number + existing parent), return an unsaved Roster ready for .save.
  # Returns nil to fall through to normal Resource creation.
  def maybe_build_subordinate_roster
    p = resource_params
    order_num = p[:order_number].to_s.strip
    return nil unless order_num.include?('.') && p[:incident_id].present? && p[:category].present?

    base, child = order_num.split('.', 2)
    return nil if base.blank? || child.blank?

    parent = Resource.where(incident_id: p[:incident_id],
                            category:    p[:category],
                            order_number: base).first
    return nil unless parent

    parent.rosters.build(
      name:         p[:name],
      position:     p[:position].presence || parent.position,
      agency:       p[:agency].presence   || parent.agency,
      order_number: child
    )
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
  #
  # Enqueues IsuiteImportJob and redirects to the progress page. The
  # heavy lifting runs on the worker dyno so the request returns in
  # milliseconds instead of racing Heroku's 30-second H12 timeout.
  def apply_isuite_import
    @incident = Incident.find(params[:incident_id])
    staging   = IsuiteImportStaging.find_active(params[:import_token])
    unless staging
      redirect_to incident_resources_path(@incident),
                  alert: "Import preview expired (>#{IsuiteImportStaging::TTL.inspect} old). Please upload the CSV again."
      return
    end

    staging.record_selections!(
      resource_ids: params[:resource_ids],
      roster_ids:   params[:roster_ids]
    )
    # Keep the staging row alive past its 30-min TTL — the job needs the
    # CSV, and the user needs the progress + result page afterwards.
    staging.update!(expires_at: 2.hours.from_now)

    enqueued = IsuiteImportJob.perform_later(staging.id)
    staging.update!(job_id: enqueued.provider_job_id || enqueued.job_id)

    redirect_to isuite_import_progress_incident_resources_path(@incident,
                                                               import_token: staging.token)
  end

  # GET /incidents/:incident_id/resources/isuite_import_progress?import_token=…
  # The "working on it" page the user lands on after submitting the
  # apply form. Polls isuite_import_status every couple seconds via JS;
  # swaps to the result summary once the job finishes.
  def isuite_import_progress
    @incident = Incident.find(params[:incident_id])
    @staging  = IsuiteImportStaging.find_by(token: params[:import_token])
    unless @staging
      redirect_to incident_resources_path(@incident),
                  alert: "Import record not found or already expired."
      return
    end
    @import_token = @staging.token
  end

  # GET /incidents/:incident_id/resources/isuite_import_status?import_token=…
  # JSON polled by the progress page every ~2s. Returns the staging
  # record's status + (when done) the result summary / error.
  def isuite_import_status
    # Same URL polled over and over — without this, some browsers will
    # serve the first "running" response from cache for the whole life
    # of the job and the UI never sees "succeeded".
    response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate'
    response.headers['Pragma']        = 'no-cache'

    @incident = Incident.find(params[:incident_id])
    staging   = IsuiteImportStaging.find_by(token: params[:import_token])
    if staging.nil?
      render json: { status: 'missing' }, status: :not_found
      return
    end

    payload = {
      status:       staging.status,
      done:         staging.done?,
      started_at:   staging.started_at,
      finished_at:  staging.finished_at,
      elapsed_sec:  staging.started_at ? ((staging.finished_at || Time.current) - staging.started_at).to_i : 0
    }
    if staging.succeeded?
      # formats: [:html] is required — this action responds as JSON, so
      # without it Rails looks for _isuite_result_summary.json.erb and
      # raises MissingTemplate.
      payload[:summary_html] = view_context.render(partial: 'resources/isuite_result_summary',
                                                   formats: [:html],
                                                   locals: { result: staging.result_hash })
      payload[:return_url]   = incident_resources_path(@incident)
    elsif staging.failed?
      payload[:error_message] = staging.error_message
      payload[:return_url]    = incident_resources_path(@incident)
    end
    render json: payload
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
