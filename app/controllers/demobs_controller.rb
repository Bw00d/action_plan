class DemobsController < ApplicationController
  before_action :set_demob, only: %i[ show edit update destroy ]
  
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  # GET /demobs or /demobs.json
  def index
    @demobs = Demob.all
  end

  # GET /demobs/1 or /demobs/1.json
  def show
    @resource = Resource.find(params[:resource_id])
    @incident = Incident.find(@resource.incident_id)
    @demob = Demob.find(params[:id])
    @logistics_units = @demob.units[0..5]
    @finance_units = @demob.units[6..8]
    @other_units = @demob.units[9..10]
    @plans_units = @demob.units[11..13]
  end

  # GET /demobs/new
  def new
    @demob = Demob.new
  end

  # GET /demobs/1/edit
  def edit
  end

  # POST /demobs or /demobs.json
  def create
    @demob = Demob.new(demob_params)

    respond_to do |format|
      if @demob.save
        format.html { redirect_to demob_url(@demob), notice: "Demob was successfully created." }
        format.json { render :show, status: :created, location: @demob }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @demob.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /demobs/1 or /demobs/1.json
  def update
    respond_to do |format|
      if @demob.update(demob_params)
        format.html { redirect_to incident_resources_path(@demob.resource.incident) }
        format.json { render :show, status: :ok, location: @demob }
      else
        format.html { render :show, status: :unprocessable_entity }
        format.json { render json: @demob.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /demobs/:id/undo — reverse a demob. Clears the demob's
  # actual_release_date AND the resource's release_date (or roster's
  # released_at) directly, so a "stuck" record where those two fell
  # out of sync is fixed on click. Also destroys any DemobNotification.
  def undo
    @demob = Demob.find(params[:id])
    Demob.transaction do
      @demob.update_columns(actual_release_date: nil, actual_release_time: nil)
      if @demob.roster
        @demob.roster.update_columns(released_at: nil) if @demob.roster.released_at.present?
      else
        @demob.resource.update_columns(release_date: nil) if @demob.resource.release_date.present?
      end
      @demob.demob_notification&.destroy
    end
    redirect_to incident_resources_path(@demob.resource.incident),
                notice: "Un-demobbed #{@demob.resource.cat}#{@demob.resource.order_number}. Drag them back to their column on the T-cards board."
  end

  # DELETE /demobs/1 or /demobs/1.json
  def destroy
    @demob.destroy

    respond_to do |format|
      format.html { redirect_to demobs_url, notice: "Demob was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_demob
      @demob = Demob.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def demob_params
      params.require(:demob).permit(:resource_id, :remarks, :edd, :edt, :destination, :travel_method, 
                                    :manifest, :manifest_number, :ron, :actual_release_date, :actual_release_time, 
                                    :eta, :contact_enroute, :agency_notified, :reassigned, :new_incident, 
                                    :new_incident_number, :new_order_number, :prepared_by, :pb_position, :date,
                                    :new_location, :time, :estimated_arrival_date)
    end
end
