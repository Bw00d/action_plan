class RostersController < ApplicationController
  include SkipAuthorization

  before_action :set_roster, only: [:promote]

  # POST /rosters/:id/promote
  def promote
    if @roster.promoted?
      redirect_back fallback_location: root_path, alert: "Already promoted."
      return
    end

    @roster.promote!
    redirect_back fallback_location: root_path, notice: "Promoted #{@roster.name} to its own T-card."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: root_path, alert: "Could not promote: #{e.message}"
  end

  private

  def set_roster
    @roster = Roster.find(params[:id])
  end
end
