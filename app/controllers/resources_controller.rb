class ResourcesController < ApplicationController
  before_action :set_resource, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  skip_before_action :authenticate_user!

  # GET /resources
  # GET /resources.json
  def index
    @incident = Incident.find(params[:incident_id])
    @resource = Resource.new
    @resources = @incident.resources.order(:category, :order_number)
    @overhead = @resources.overhead
    @equipment = @resources.equipment
    @crews = @resources.crew
    @aircraft = @resources.aircraft
  end

  # GET /resources/1
  # GET /resources/1.json
  def show
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
      else
        format.html { render :edit }
        format.json { respond_with_bip(@resource) }
      end
    end
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
                                       :r_and_r)
    end
end
