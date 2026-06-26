class RequestsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  def index
    @requests = @incident.requests.order(:req_catalog_name, :req_number_prefix, :req_number)
    @grouped = @requests.group_by(&:req_catalog_name)
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end
end
