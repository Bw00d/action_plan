class RequestCheckinsController < ApplicationController
  include SkipAuthorization

  before_action :set_context

  def new
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
  end

  def create
    @resource = @incident.resources.new(resource_params)
    if @resource.save
      populate_roster_from_subordinates(@resource, @request)
      redirect_to incident_requests_path(@incident),
                  notice: "Checked in #{@resource.name} (#{@resource.full_order_number})."
    else
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
    @request  = @incident.requests.find(params[:request_id])
  end

  def resource_params
    params.require(:resource).permit(
      :name, :leader, :number_personnel, :position, :agency,
      :order_number, :category, :phone, :email, :comment,
      :fwd, :checkin_date, :assignment_length,
      :jetport, :return_city, :return_state
    )
  end
end
