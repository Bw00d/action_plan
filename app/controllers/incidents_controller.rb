require 'net/http'
require 'uri'

class IncidentsController < ApplicationController
  before_action :set_incident, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  
  def users
    @incident = Incident.find(params[:id])
    @users = @incident.users
  end

  # GET /incidents/:id/perimeter.json
  # Fetches the fire perimeter for this incident from Wildland Fire
  # Interagency Geospatial Services (WFIGS) by matching on incident name +
  # state. Returns a GeoJSON FeatureCollection. Cached for an hour so a
  # burst of page reloads doesn't hammer the upstream service.
  def perimeter
    incident = Incident.find(params[:id])
    name  = incident.name.to_s.strip
    state = incident.state.to_s.strip.upcase

    if name.blank? || state.blank?
      render json: { type: 'FeatureCollection', features: [] } and return
    end

    # WFIGS uses "US-XX" for state codes.
    state_code = state.start_with?('US-') ? state : "US-#{state}"

    year = incident_year(incident)
    cache_key = "wfigs_perimeter/#{name}/#{state_code}/#{year}"
    body =
      begin
        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          escaped_name = name.gsub("'", "''")
          query = {
            where:            "poly_IncidentName='#{escaped_name}' AND attr_POOState='#{state_code}' AND #{year_range_clause(year)}",
            outFields:        'poly_IncidentName,attr_POOState,attr_FireDiscoveryDateTime,attr_FinalAcres,attr_IncidentSize,attr_CalculatedAcres,attr_PercentContained,attr_FireCause,attr_IrwinID',
            returnGeometry:   true,
            orderByFields:    'attr_FireDiscoveryDateTime DESC',
            resultRecordCount: 1,
            f:                'geojson'
          }
          uri = URI("https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Interagency_Perimeters/FeatureServer/0/query")
          uri.query = query.to_query
          http_response = nil
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
            http_response = http.request(Net::HTTP::Get.new(uri.request_uri))
          end
          http_response&.body
        end
      rescue StandardError => e
        Rails.logger.error("WFIGS perimeter fetch failed: #{e.class} #{e.message}")
        nil
      end

    if body.blank?
      render json: { type: 'FeatureCollection', features: [], error: 'upstream_unavailable' }, status: :bad_gateway
    else
      render body: body, content_type: 'application/geo+json'
    end
  end

  # GET /incidents/:id/irwin_data.json
  # Fetches attributes for this incident from WFIGS (which sources IRWIN),
  # normalized to match Incident's own column names. Frontend uses this to
  # present a "current vs proposed" diff before the user chooses what to
  # apply.
  def irwin_data
    incident = Incident.find(params[:id])
    name  = incident.name.to_s.strip
    state = incident.state.to_s.strip.upcase
    state_code = state.start_with?('US-') ? state : "US-#{state}"

    if name.blank? || state.blank?
      render json: { error: 'Incident name or state is not set.' }, status: :unprocessable_entity and return
    end

    year = incident_year(incident)
    cache_key = "wfigs_attrs/#{name}/#{state_code}/#{year}"
    attrs =
      begin
        Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
          escaped_name = name.gsub("'", "''")
          query = {
            where: "poly_IncidentName='#{escaped_name}' AND attr_POOState='#{state_code}' AND #{year_range_clause(year)}",
            outFields: %w[
              attr_IncidentName attr_UniqueFireIdentifier attr_IncidentSize attr_CalculatedAcres
              attr_PercentContained attr_FireCause attr_FireCauseGeneral attr_FireBehaviorGeneral
              attr_PredominantFuelGroup attr_PrimaryFuelModel
              attr_FireDiscoveryDateTime attr_ContainmentDateTime
              attr_ControlDateTime attr_FireOutDateTime attr_POOCity attr_POOCounty attr_POOState
              attr_InitialLatitude attr_InitialLongitude attr_IncidentManagementOrg
              attr_FireMgmtComplexity attr_IncidentShortDescription attr_IrwinID
              attr_POOProtectingAgency attr_POOProtectingUnit attr_EstimatedCostToDate
              attr_FSJobCode attr_FSOverrideCode
            ].join(','),
            returnGeometry:    false,
            orderByFields:     'attr_FireDiscoveryDateTime DESC',
            resultRecordCount: 1,
            f:                 'json'
          }
          uri = URI("https://services3.arcgis.com/T4QMspbfLg3qTGWY/arcgis/rest/services/WFIGS_Interagency_Perimeters/FeatureServer/0/query")
          uri.query = query.to_query
          http_response = nil
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
            http_response = http.request(Net::HTTP::Get.new(uri.request_uri))
          end
          parsed = JSON.parse(http_response.body) rescue {}
          parsed.dig('features', 0, 'attributes')
        end
      rescue StandardError => e
        Rails.logger.error("IRWIN fetch failed: #{e.class} #{e.message}")
        nil
      end

    if attrs.blank?
      render json: { error: 'No matching incident found in WFIGS.' }, status: :not_found and return
    end

    render json: {
      proposed:         normalize_wfigs_attrs(attrs),
      financial_codes:  proposed_financial_codes(attrs),
      source:           'WFIGS / IRWIN',
      fetched_at:       Time.current
    }
  end

  private

  # Normalizes WFIGS attribute names to Incident column names so the modal
  # can just say "here's what would go into `cause`" without the client
  # needing to know about WFIGS field naming.
  def normalize_wfigs_attrs(attrs)
    acres = attrs['attr_IncidentSize'] || attrs['attr_CalculatedAcres']
    pct   = attrs['attr_PercentContained']
    # Prefer IRWIN's human-friendly short description (e.g. "10 Miles E from
    # Ruby, AK") over the raw city/county pair, which is often incomplete.
    loc = attrs['attr_IncidentShortDescription'].to_s.strip.presence ||
          [attrs['attr_POOCity'], attrs['attr_POOCounty']].reject { |v| v.blank? }.join(', ')

    # Ownership formatted as "AGENCY - UNIT" (e.g. "BLM - AKTAD").
    ownership = [attrs['attr_POOProtectingAgency'], attrs['attr_POOProtectingUnit']]
                  .reject { |v| v.blank? }.join(' - ')

    # P Code formatted as "FSJobCode (FSOverrideCode)" — e.g. "PD (1542)".
    fs_job      = attrs['attr_FSJobCode'].to_s.strip
    fs_override = attrs['attr_FSOverrideCode'].to_s.strip
    p_code = if fs_job.present? && fs_override.present?
               "#{fs_job} (#{fs_override})"
             elsif fs_job.present?
               fs_job
             end

    # NOTE on IC: WFIGS doesn't publish individual Incident Commander names
    # (they only exist in IRWIN's authenticated feed). We used to map the
    # Incident Management Org into `ic`, but that overwrote real IC names
    # each time someone hit Populate. Leaving `ic` out of the mapping so
    # manually-entered names stay put.
    {
      name:              attrs['attr_IncidentName'],
      number:            attrs['attr_UniqueFireIdentifier'],
      size:              acres ? acres.round : nil,
      percent_contained: pct ? pct.round : nil,
      status:            derive_status(attrs),
      cause:             attrs['attr_FireCause'] || attrs['attr_FireCauseGeneral'],
      fire_behavior:     attrs['attr_FireBehaviorGeneral'],
      fuel_type:         attrs['attr_PredominantFuelGroup'].presence || attrs['attr_PrimaryFuelModel'],
      start_date:        epoch_to_date(attrs['attr_FireDiscoveryDateTime']),
      containment_date:  epoch_to_date(attrs['attr_ContainmentDateTime']),
      control_date:      epoch_to_date(attrs['attr_ControlDateTime']),
      out_date:          epoch_to_date(attrs['attr_FireOutDateTime']),
      location:          loc.presence,
      latitude:          attrs['attr_InitialLatitude']&.to_s,
      longitude:         attrs['attr_InitialLongitude']&.to_s,
      complexity:        attrs['attr_FireMgmtComplexity'],
      ownership:         ownership.presence,
      cost:              attrs['attr_EstimatedCostToDate']&.to_i,
      p_code:            p_code
    }.compact.reject { |_, v| v.respond_to?(:empty?) && v.empty? }
  end

  # Financial codes we can derive from WFIGS attributes. BLM's fire-tracking
  # identifier is the FireCode; USFS uses a composite of JobCode + FireCode +
  # OverrideCode. Everything else (SOA, state DNRs, compacts, etc.) has to
  # be entered manually and is left untouched.
  def proposed_financial_codes(attrs)
    codes = {}
    fire_code = attrs['attr_FireCode'].to_s.strip
    codes['BLM'] = fire_code if fire_code.present?

    job = attrs['attr_FSJobCode'].to_s.strip
    override = attrs['attr_FSOverrideCode'].to_s.strip
    usfs_parts = [job, fire_code].reject(&:blank?)
    usfs = usfs_parts.join(' ')
    usfs += " (#{override})" if override.present? && usfs.present?
    codes['USFS'] = usfs if usfs.present?

    codes
  end

  # Derives a human-readable status by walking the fire's lifecycle
  # milestones from latest to earliest. Order matters: an Out fire is also
  # Controlled and Contained, but should be labelled "Out".
  def derive_status(attrs)
    return 'Out'        if attrs['attr_FireOutDateTime'].present?
    return 'Controlled' if attrs['attr_ControlDateTime'].present?
    pct = attrs['attr_PercentContained']
    return 'Uncontained' if pct.nil? || pct < 100
    'Contained'
  end

  def epoch_to_date(ms)
    return nil unless ms
    Time.at(ms.to_f / 1000).utc.to_date.iso8601
  end

  # Pick the "when" year for this incident so WFIGS queries disambiguate
  # same-named fires across years. Prefer the manually-entered start_date,
  # then the IROC initial_date, then the record's created_at, and finally
  # the current year as a last-ditch default.
  def incident_year(incident)
    (incident.start_date || incident.initial_date || incident.created_at || Time.current).year
  end

  # WFIGS' where-clause fragment restricting discovery-date to the given
  # calendar year. Uses the ArcGIS TIMESTAMP literal so the format is
  # unambiguous across services.
  def year_range_clause(year)
    "attr_FireDiscoveryDateTime >= TIMESTAMP '#{year}-01-01 00:00:00' AND " \
    "attr_FireDiscoveryDateTime <= TIMESTAMP '#{year}-12-31 23:59:59'"
  end

  public
  # GET /incidents
  # GET /incidents.json
  def index
    # Owner (user_id) + shared collaborators (incidents_users join table),
    # deduped so an owner who is also in the join table isn't listed twice.
    owned  = Incident.where(user_id: current_user.id)
    shared = Incident.joins(:users).where(users: { id: current_user.id })
    @incidents = Incident.where(id: (owned.pluck(:id) + shared.pluck(:id)).uniq)
  end

  # GET /incidents/1
  # GET /incidents/1.json
  def show
    @resources = @incident.resources.order(:category, :order_number)
    @resource = Resource.new
  end

  # GET /incidents/new
  def new
    @incident = Incident.new
  end

  # GET /incidents/1/edit
  def edit
  end

  # POST /incidents
  # POST /incidents.json
  def create
    @incident = Incident.new(incident_params)

    respond_to do |format|
      if @incident.save
        @incident.users << current_user
        Incidents::SeedOrgChart.call(@incident)
        format.html { redirect_to incident_path(@incident) }
        format.js { }
        format.json { render incident_path(@incident), status: :created, location: @incident }
      else
        format.html { render :new }
        format.json { render json: @incident.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /incidents/1
  # PATCH/PUT /incidents/1.json
  def update
    respond_to do |format|
      if @incident.update(incident_params)
        format.html { redirect_to incident_plans_path(@incident) }
        format.json { render :show, status: :ok, location: @incident }
      else
        format.html { redirect_to incident_plans_path(@incident) }
        format.json { render json: @incident.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /incidents/1
  # DELETE /incidents/1.json
  def destroy
    @incident.destroy
    respond_to do |format|
      format.html { redirect_to incidents_url, notice: 'Incident was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def invite
    @incident = Incident.find(params[:incident_id])
    email = params[:invite].to_s.strip.downcase

    if email.blank?
      redirect_back(fallback_location: incident_users_path(@incident), alert: "Please enter an email address.")
      return
    end

    existing = User.find_by(email: email)

    if existing
      if @incident.users.exists?(existing.id)
        notice = "#{existing.email} is already a collaborator on this incident."
      else
        @incident.users << existing
        InvitationMailer.added_to_incident(existing, @incident, current_user).deliver_later
        notice = "Added #{existing.email} and sent them a notification."
      end
      redirect_to incident_users_path(@incident), notice: notice
    else
      # Fresh invite: create a placeholder user with a random password so
      # Devise's :validatable is satisfied, generate a raw invitation token
      # (piggybacks on Devise's confirmation_token infrastructure), and send
      # the accept-invitation email.
      raw_token, digest = Devise.token_generator.generate(User, :confirmation_token)
      new_user = User.new(
        email:                 email,
        first_name:            "Pending",
        last_name:             "Invitee",
        password:              SecureRandom.hex(16) + "Aa1", # meets password_strength rules
        password_confirmation: nil
      )
      new_user.password_confirmation = new_user.password
      new_user.skip_confirmation_notification! if new_user.respond_to?(:skip_confirmation_notification!)
      new_user.confirmation_token   = digest
      new_user.confirmation_sent_at = Time.current
      if new_user.save
        @incident.users << new_user
        InvitationMailer.invite_new_user(new_user, @incident, current_user, raw_token).deliver_later
        redirect_to incident_users_path(@incident), notice: "Invitation sent to #{email}."
      else
        redirect_to incident_users_path(@incident), alert: "Couldn't invite #{email}: #{new_user.errors.full_messages.to_sentence}"
      end
    end
  end

  def remove_user
    @incident = Incident.find(params[:incident_id])
    @user = User.find(params[:user]) 
    @incident.users.delete(@user)
    respond_to do |format|
      format.html { redirect_back(fallback_location: "#{@incident.id}/users") }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_incident
      @incident = Incident.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def incident_params
      params.require(:incident).permit(:name, :number, :p_code, :user_id, :financial_code, :size,
                                       :incident_type, :complexity, :status, :cause, :fuel_type,
                                       :start_date, :containment_date, :control_date, :out_date,
                                       :percent_contained, :location, :ownership, :protection,
                                       :latitude, :longitude, :ic, :fire_behavior, :state, :cost )
    end
end