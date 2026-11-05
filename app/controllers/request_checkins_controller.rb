# Checks a Request in as a Resource. Also reached without a request, from
# an unmatched remote-checkin submission ("Check in anyway" on the queue):
# the form is pre-filled from the submission and the typed request number,
# and if the (possibly corrected) number matches a request on save, that
# request is linked and its subordinates fill the roster as usual.
class RequestCheckinsController < ApplicationController
  include SkipAuthorization

  before_action :set_context

  def new
    if @request.nil?
      @resource = @incident.resources.new(category:          @remote_checkin.category,
                                          order_number:      @remote_checkin.typed_order_number,
                                          assignment_length: 14)
      apply_remote_checkin_overlay(@resource)
      return
    end

    if !@request.checkinable?
      redirect_to incident_requests_path(@incident), alert: "Supply requests aren't checked in as Resources."
      return
    end
    if @request.subordinate?
      redirect_to incident_requests_path(@incident), alert: "Subordinate requests aren't individually checked in."
      return
    end

    # If the request has subordinates, we can pre-fill the leader name (the
    # first direct subordinate, e.g. C-6.1 = the crew boss) and the personnel
    # count (total descendants). For a lone request with no subordinates we
    # can't infer either — user fills them in manually.
    children_map = Request.build_children_map(@incident.requests)
    descendants  = Request.descendants_of(@request.req_number, children_map)
    direct_subs  = Request.direct_children_of(@request.req_number, children_map)
    personnel    = descendants.any? ? descendants.size : nil

    # Leader-name derivation:
    # - Resource has subordinates → use the first direct sub's name
    #   (same as before; whichever sub later gets marked :primary via
    #   the roster UI will take over via Roster#sync_resource_leader).
    # - Overhead single person (no subs) → format the resource's own
    #   name "LAST, FIRST MIDDLE" into "FIRST MIDDLE LAST" so the
    #   Leader column reads naturally.
    # - Anything else without subs → leave blank for manual entry.
    raw_name = @request.suggested_resource_name
    leader_name =
      if direct_subs.any?
        direct_subs.first&.suggested_resource_name
      elsif @request.resource_category == 'OVERHEAD'
        Resource.format_leader_name(raw_name)
      end

    @resource = @incident.resources.new(
      name:              raw_name,
      category:          @request.resource_category,
      position:          @request.filled_catalog_item_code,
      agency:            @request.res_prov_agency_abbrev,
      order_number:      @request.suggested_order_number,
      leader:            leader_name,
      number_personnel:  personnel,
      jetport:           @request.jet_port,
      assignment_length: 14
    )

    # If the admin arrived from the remote-checkin review queue, overlay
    # the self-reported fields on top of the request-derived defaults.
    # Submitted values take precedence — if the resource corrected a
    # position/leader/personnel count, trust what they wrote. The
    # @remote_checkin ivar also surfaces to the view so it can show a
    # "promoting submission from X" banner and carries into #create.
    apply_remote_checkin_overlay(@resource)
  end

  def create
    @resource = @incident.resources.new(resource_params)
    if @resource.save
      request = @request || request_matching(@resource)
      populate_roster_from_subordinates(@resource, request) if request
      promote_remote_checkin_if_any(@resource, request)
      redirect_to(@request ? incident_requests_path(@incident) : incident_remote_checkins_path(@incident),
                  notice: "Checked in #{@resource.name} (#{@resource.full_order_number}).")
    else
      load_remote_checkin
      render :new
    end
  end

  private

  # When a checkinable request has subordinate requests (e.g. a strike team
  # E-209 with STENs, engines, and crew members below, or a crew C-1 with
  # crew members below), snapshot the whole subtree into rosters so the
  # newly-created Resource carries a personnel manifest.
  def populate_roster_from_subordinates(resource, request)
    children_map = Request.build_children_map(@incident.requests)
    descendants  = Request.descendants_of(request.req_number, children_map)
    descendants.each_with_index do |req, i|
      resource.rosters.create!(
        request:      req,
        name:         req.suggested_resource_name,
        position:     req.filled_catalog_item_code,
        order_number: req.suggested_order_number,
        position_num: i + 1,
        agency:       req.res_prov_agency_abbrev
      )
    end
  end


  def set_context
    @incident = Incident.find(params[:incident_id])
    load_remote_checkin
    if params[:request_id]
      @request = @incident.requests.find(params[:request_id])
    elsif @remote_checkin.nil?
      # The request-less route only makes sense for a submission.
      raise ActiveRecord::RecordNotFound
    end
  end

  # Checked in without a request: the order number may have been fixed
  # on the form, so see if it now names a request that can own the
  # resource (not a subordinate or supply line).
  def request_matching(resource)
    req = @incident.requests.find_by(req_number: resource.full_order_number)
    req if req&.checkinable? && !req.subordinate?
  end

  # Look up a remote-checkin submission the admin is promoting. The id
  # comes either as a query param (new) or hidden field (create). We
  # scope to this incident so stale ids from other incidents don't
  # leak overlays.
  def load_remote_checkin
    id = params[:remote_checkin_id].presence || params.dig(:resource, :remote_checkin_id).presence
    return unless id
    @remote_checkin = @incident.remote_checkins.find_by(id: id)
  end

  def apply_remote_checkin_overlay(resource)
    return unless @remote_checkin
    rc = @remote_checkin
    # Overlay precedence: self-reported wins over request-derived,
    # because the resource knows better. Leave values the resource
    # didn't fill in untouched.
    resource.name              = rc.name             if rc.name.present?
    resource.position          = rc.position         if rc.position.present?
    resource.agency            = rc.agency           if rc.agency.present?
    resource.leader            = rc.effective_leader if rc.effective_leader.present?
    resource.phone             = rc.phone            if rc.phone.present?
    resource.email             = rc.email            if rc.email.present?
    resource.number_personnel  = rc.number_personnel if rc.number_personnel.present?
    resource.fwd               = rc.first_work_day   if rc.first_work_day.present?
    resource.checkin_date      = Date.current
    resource.return_city       = rc.demob_city       if rc.demob_city.present?
    resource.return_state      = rc.demob_state      if rc.demob_state.present?

    # Native columns for the previously-free-text fields — stored on
    # the Resource now so they survive beyond the remote_checkin row
    # and show up on tally/CSV exports.
    resource.agency_address              = rc.agency_address              if rc.agency_address.present?
    resource.emergency_contact           = rc.emergency_contact           if rc.emergency_contact.present?
    resource.mobilization_date           = rc.mobilization_date           if rc.mobilization_date.present?
    resource.transportation_method       = rc.transportation_method       if rc.transportation_method.present?
    resource.from_other_incident         = rc.from_other_incident         unless rc.from_other_incident.nil?
    resource.other_incident_name         = rc.other_incident_name         if rc.other_incident_name.present?
    resource.other_incident_req_number   = rc.other_incident_req_number   if rc.other_incident_req_number.present?
    resource.prev_incident_first_day_worked = rc.first_day_worked         if rc.first_day_worked.present?
  end

  # After the resource saves, mark the submission promoted so it
  # falls off the pending queue, and link to the resource we just
  # created so the audit trail is intact.
  def promote_remote_checkin_if_any(resource, request)
    return unless @remote_checkin
    @remote_checkin.update!(status: :promoted,
                            promoted_at: Time.current,
                            promoted_resource_id: resource.id,
                            request_id: request&.id || @remote_checkin.request_id)
  end

  def resource_params
    params.require(:resource).permit(
      :name, :leader, :number_personnel, :position, :agency,
      :order_number, :category, :phone, :email, :comment,
      :fwd, :checkin_date, :assignment_length,
      :jetport, :return_city, :return_state,
      # Fields added for the remote-checkin flow — dispatchers can
      # fill them in the manual form too (see the "Additional details"
      # fieldset in request_checkins/new).
      :agency_address, :emergency_contact, :mobilization_date,
      :transportation_method, :from_other_incident,
      :other_incident_name, :other_incident_req_number,
      :prev_incident_first_day_worked
    )
  end
end
