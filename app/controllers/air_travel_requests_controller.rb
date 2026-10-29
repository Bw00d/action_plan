class AirTravelRequestsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :set_request, only: [:edit, :update, :destroy, :to_pdf]
  before_action :set_resource_options, only: [:new, :create, :edit, :update]

  # GET /incidents/:incident_id/air_travel_requests
  def index
    @requests = @incident.air_travel_requests.order(created_at: :desc)
  end

  # GET /incidents/:incident_id/air_travel_requests/new(?resource_id=)
  # Picking a resource reloads this page with resource_id so the form
  # comes back pre-filled from that resource.
  def new
    resource = @incident.resources.find_by(id: params[:resource_id]) if params[:resource_id].present?
    @travel_request = AirTravelRequest.prefilled_for(@incident, resource)
  end

  def create
    @travel_request = @incident.air_travel_requests.new(request_params)
    if @travel_request.save
      redirect_to incident_air_travel_requests_path(@incident),
                  notice: "Air travel request for #{@travel_request.resource_name} saved."
    else
      render :new
    end
  end

  def edit; end

  def update
    if @travel_request.update(request_params)
      redirect_to incident_air_travel_requests_path(@incident),
                  notice: "Air travel request for #{@travel_request.resource_name} updated."
    else
      render :edit
    end
  end

  def destroy
    @travel_request.destroy
    redirect_to incident_air_travel_requests_path(@incident),
                notice: 'Air travel request deleted.'
  end

  # GET /incidents/:incident_id/air_travel_requests/:id/to_pdf
  def to_pdf
    html = render_to_string(template: 'air_travel_requests/to_pdf', layout: false)

    pdf = Grover.new(html,
      display_url:      request.base_url,
      format:           'Letter',
      margin:           { top: '0.5in', right: '0.5in', bottom: '0.5in', left: '0.5in' },
      print_background: true
    ).to_pdf

    label = (@travel_request.request_number.presence || @travel_request.id).to_s.parameterize(preserve_case: true)
    send_data pdf, filename: "air_travel_request_#{label}.pdf",
                   type: 'application/pdf', disposition: 'inline'
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def set_request
    @travel_request = @incident.air_travel_requests.find(params[:id])
  end

  def set_resource_options
    @resource_options = @incident.resources.where(spacer: false)
                                 .order(:category, :order_number)
                                 .map { |r| ["#{r.full_order_number} — #{r.name}", r.id] }
  end

  def request_params
    params.require(:air_travel_request).permit(
      :resource_id, :travel_type, :request_number, :resource_name, :unit_id,
      :release_city, :release_state, :available_date, :available_time,
      :travel_hours, :travel_minutes, :depart_from, :return_to,
      *AirTravelRequest::TRAVEL_QUESTIONS.map(&:first),
      :special_instructions, :last_date_available, :reassignment_quals
    )
  end
end
