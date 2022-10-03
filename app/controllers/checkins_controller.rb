class CheckinsController < ApplicationController
  before_action :set_checkin, only: %i[ show edit update destroy ]

  include SkipAuthorization
  skip_before_action :authenticate_user!

  # GET /checkins or /checkins.json
  def index
    @incident = Incident.find(params[:incident_id])
    @checkins = @incident.checkins
  end

  # GET /checkins/1 or /checkins/1.json
  def show
  end

  # GET /checkins/new
  def new
    @checkin = Checkin.new
    @incident = Incident.find(params[:incident_id])
  end

  # GET /checkins/1/edit
  def edit
  end

  # POST /checkins or /checkins.json
  def create
    @checkin = Checkin.new(checkin_params)
    @incident = Incident.find(params[:incident_id])

    respond_to do |format|
      if @checkin.save
        format.html { render :confirmation }
        format.json { render :show, status: :created, location: @checkin }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @checkin.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /checkins/1 or /checkins/1.json
  def update
    respond_to do |format|
      if @checkin.update(checkin_params)
        format.html { redirect_to checkin_url(@checkin), notice: "Checkin was successfully updated." }
        format.json { render :show, status: :ok, location: @checkin }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @checkin.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /checkins/1 or /checkins/1.json
  def destroy
    @checkin.destroy

    respond_to do |format|
      format.html { redirect_to checkins_url, notice: "Checkin was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def confirmation
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_checkin
      @checkin = Checkin.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def checkin_params
      params.require(:checkin).permit(:name, :leader, :number_personnel, :position, :agency, 
                                       :order_number, :checkin_date, :incident_id, :category,
                                       :first_day_worked, :contact_info, :home_unit, :other_quals,
                                       :other_incident, :other_incident_name, :resource_id )
    end
end
