class SafetyMessagesController < ApplicationController
  before_action :set_safety_message, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  # skip_before_action :authenticate_user!

  # GET /safety_messages
  # GET /safety_messages.json
  def index
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @safety_message = SafetyMessage.new
    respond_to do |format|
      if @plan.safety_message
        format.html { redirect_to incident_plan_safety_message_path(@incident, @plan, @plan.safety_message)}
      else
        format.html { render 'index' }
      end
    end
  end

  # GET /safety_messages/1
  # GET /safety_messages/1.json
  def show
    @safety_message = SafetyMessage.find(params[:id])
    @plan = Plan.find(@safety_message.plan_id)
    @incident = Incident.find(@plan.incident_id)
  end

  def safety_message_to_pdf
    @safety_message = SafetyMessage.find(params[:id])
    @plan = Plan.find(@safety_message.plan_id)
    @incident = Incident.find(@plan.incident_id)
  end


  # GET /safety_messages/new
  def new
    @safety_message = SafetyMessage.new
  end

  # GET /safety_messages/1/edit
  def edit
  end

  # POST /safety_messages
  # POST /safety_messages.json
  def create
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @safety_message = SafetyMessage.new(safety_message_params)
    
    respond_to do |format|
      if @safety_message.save
        format.html { redirect_to incident_plan_safety_message_path(@incident, @plan, @safety_message) }
        format.json { render :show, status: :created, location: @safety_message }
      else
        format.html { render :new }
        format.json { render json: @safety_message.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /safety_messages/1
  # PATCH/PUT /safety_messages/1.json
  def update
    @safety_message = SafetyMessage.find params[:id]

    respond_to do |format|
      if @safety_message.update_attributes(safety_message_params)
        format.html { redirect_back(fallback_location: root_path) }
        format.json { respond_with_bip(@safety_message) }
      else
        format.html { render :action => "show" }
        format.json { respond_with_bip(@safety_message) }
      end
    end
  end

  # DELETE /safety_messages/1
  # DELETE /safety_messages/1.json
  def destroy
    @safety_message.destroy
    respond_to do |format|
      format.html { redirect_to safety_messages_url, notice: 'Safety message was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

    def download_safety_message
    @safety_message = SafetyMessage.find(params[:id])
    safety_message = render_to_string "safety_message_to_pdf.html.erb", layout: "pdf"

    respond_to do |format|
      format.html { render html: safety_message }
      format.pdf { render_pdf safety_message, filename: t(".filename", id: @safety_message.id) }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_safety_message
      @safety_message = SafetyMessage.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def safety_message_params
      params.require(:safety_message).permit(:hazards, :narrative, :prepared_by, :plan_id)
    end
end
