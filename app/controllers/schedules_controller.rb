class SchedulesController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :set_schedule, only: [:update, :destroy]

  def index
    @schedules = @incident.schedules
    # NOTE: build @schedule via Schedule.new (not @incident.schedules.new)
    # to avoid appending the unsaved record to @schedules — an association
    # proxy .new pollutes the in-memory collection.
    @schedule  = Schedule.new(incident: @incident)
  end

  def create
    next_position = (@incident.schedules.maximum(:position) || 0) + 1
    @schedule = @incident.schedules.new(schedule_params.merge(position: next_position))

    respond_to do |format|
      if @schedule.save
        format.html { redirect_to incident_schedules_path(@incident), notice: "Added #{@schedule.meeting_name}." }
      else
        @schedules = @incident.schedules
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @schedule.update(schedule_params)
        format.html { redirect_back(fallback_location: incident_schedules_path(@incident)) }
        format.json { respond_with_bip(@schedule) }
      else
        format.html { redirect_back(fallback_location: incident_schedules_path(@incident), alert: @schedule.errors.full_messages.to_sentence) }
        format.json { respond_with_bip(@schedule) }
      end
    end
  end

  def destroy
    name = @schedule.meeting_name
    @schedule.destroy
    redirect_to incident_schedules_path(@incident), notice: "Removed #{name}."
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def set_schedule
    @schedule = @incident.schedules.find(params[:id])
  end

  def schedule_params
    params.require(:schedule).permit(:meeting_name, :time, :location)
  end
end
