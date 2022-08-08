class CoversController < ApplicationController
  before_action :set_cover, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  skip_before_action :authenticate_user!
  

  # GET /covers
  # GET /covers.json
  def index
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @cover = Cover.new
    respond_to do |format|
      if @plan.cover
        format.html { redirect_to incident_plan_cover_path(@incident, @plan, @plan.cover)}
      else
        format.html { render 'index' }
      end
    end
  end

  # GET /covers/1
  # GET /covers/1.json
  def show
    @cover = Cover.find(params[:id])
    @plan = Plan.find(@cover.plan_id)
    @incident = Incident.find(@plan.incident_id)
    @block = Block.new
    @blocks = @cover.blocks.order(number: :asc)
  end

  # GET /covers/new
  def new
    @cover = Cover.new
  end

  # GET /covers/1/edit
  def edit
  end

  # POST /covers
  # POST /covers.json
  def create
    @plan = Plan.find(params[:plan_id])
    @incident = Incident.find(@plan.incident_id)
    @cover = Cover.new(cover_params)

    respond_to do |format|
      if @cover.save
        format.html { redirect_to incident_plan_cover_path(@incident, @plan, @cover) }
        format.json { render :show, status: :created, location: @cover }
      else
        format.html { render :new }
        format.json { render json: @cover.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /covers/1
  # PATCH/PUT /covers/1.json
  def update
    respond_to do |format|
      if @cover.update(cover_params)
        format.html { redirect_to @cover, notice: 'Cover was successfully updated.' }
        format.json { render :show, status: :ok, location: @cover }
      else
        format.html { render :edit }
        format.json { render json: @cover.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /covers/1
  # DELETE /covers/1.json
  def destroy
    @cover.destroy
    respond_to do |format|
      format.html { redirect_to covers_url, notice: 'Cover was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_cover
      @cover = Cover.find(params[:id])
    end

  
    # Only allow a list of trusted parameters through.
    def cover_params
      params.require(:cover).permit(:plan_id)
    end
end
