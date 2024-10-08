class IncidentsController < ApplicationController
  before_action :set_incident, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  
  def users
    @incident = Incident.find(params[:id])
    @users = @incident.users
  end
  # GET /incidents
  # GET /incidents.json
  def index
    @incidents = current_user.incidents
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
    @invite = params[:invite]
    # @invitee = User.where('email LIKE ?', "%#{@invite}%")
    @invitee = User.find_by(email: params[:invite])
    if @invitee
      @incident.users << @invitee
    else
      @invited = User.create!(email: params[:invite], password: "Changm3!", password_confirmation: "Changm3!", 
                              first_name: "Firstname", last_name: "Lastname")
      @incident.users << @invited
    end
    respond_to do |format|
      format.html { redirect_back(fallback_location: "#{@incident.id}/users") }
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
                                       :latitude, :longitude, :ic, :fire_behavior )
    end
end