class TeamsController < ApplicationController
  before_action :set_team, only: [:show, :edit, :update, :destroy]
  include SkipAuthorization
  skip_before_action :authenticate_user!

  # GET /teams
  # GET /teams.json
  def index
    @teams = Team.all
  end

  # GET /teams/1
  # GET /teams/1.json
  def show
  end

  # GET /teams/new
  def new
    @team = Team.new
  end

  # GET /teams/1/edit
  def edit
  end

  # POST /teams
  # POST /teams.json
  def create
    @team = Team.new(team_params)

    respond_to do |format|
      if @team.save
        format.html { redirect_back(fallback_location: root_path) }
        format.json { redirect_back(fallback_location: root_path) }
      else
        format.html { redirect_back(fallback_location: root_path) }
        format.json { redirect_back(fallback_location: root_path) }
      end
    end
  end

  # PATCH/PUT /teams/1
  # PATCH/PUT /teams/1.json
  def update
    @team = Team.find params[:id]
    
    respond_to do |format|
      if @team.update_attributes(team_params)
        format.html { redirect_back(fallback_location: root_path) }
        format.json { respond_with_bip(@team) }
      else
        format.html { render :action => "show" }
        format.json { respond_with_bip(@team) }
      end
    end
  end

  # DELETE /teams/1
  # DELETE /teams/1.json
  def destroy
    @team.destroy
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path) }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_team
      @team = Team.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def team_params
      params.require(:team).permit(:resource_name, :position, :staff, :plan_id)
    end
end
