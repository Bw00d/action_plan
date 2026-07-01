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

    @resource = @incident.resources.new(
      name:              @request.suggested_resource_name,
      category:          @request.resource_category,
      position:          @request.filled_catalog_item_code,
      agency:            @request.res_prov_agency_abbrev,
      order_number:      @request.suggested_order_number,
      assignment_length: 14
    )
  end

  def create
    @resource = @incident.resources.new(resource_params)
    if @resource.save
      redirect_to incident_requests_path(@incident),
                  notice: "Checked in #{@resource.name} (#{@resource.full_order_number})."
    else
      render :new
    end
  end

  private

  def set_context
    @incident = Incident.find(params[:incident_id])
    @request  = @incident.requests.find(params[:request_id])
  end

  def resource_params
    params.require(:resource).permit(
      :name, :leader, :number_personnel, :position, :agency,
      :order_number, :category, :phone, :email, :comment,
      :fwd, :checkin_date, :assignment_length
    )
  end
end
