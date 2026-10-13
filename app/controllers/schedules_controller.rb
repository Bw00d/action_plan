class SchedulesController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :set_schedule, only: [:update, :destroy]

  def index
    # First visit for this user → seed their personal "My Schedule" with
    # the same default meetings as the incident schedule.
    Schedule.seed_defaults!(@incident, user: current_user) if current_user

    @meeting_schedules = ordered_schedules(user_id: nil)
    @my_schedules      = current_user ? ordered_schedules(user_id: current_user.id) : Schedule.none

    # NOTE: build via Schedule.new (not @incident.schedules.new) to avoid
    # appending the unsaved record to the ordered lists above — an
    # association proxy .new pollutes the in-memory collection.
    @schedule = Schedule.new(incident: @incident)
  end

  def create
    # scope: "my" → owned by current user (My Schedule panel). Anything
    # else (including nil / blank) → shared Meeting Schedule.
    owner_id = params[:schedule][:scope].to_s == 'my' && current_user ? current_user.id : nil

    next_position = (@incident.schedules.where(user_id: owner_id).maximum(:position) || 0) + 1
    @schedule = @incident.schedules.new(
      schedule_params.merge(position: next_position, user_id: owner_id)
    )

    respond_to do |format|
      if @schedule.save
        format.html { redirect_to incident_schedules_path(@incident), notice: "Added #{@schedule.meeting_name}." }
      else
        @meeting_schedules = ordered_schedules(user_id: nil)
        @my_schedules      = current_user ? ordered_schedules(user_id: current_user.id) : Schedule.none
        format.html { render :index, status: :unprocessable_entity }
      end
    end
  end

  def update
    return head :forbidden unless editable_by_current_user?(@schedule)

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
    return head :forbidden unless editable_by_current_user?(@schedule)

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

  # Meeting-schedule rows (user_id: nil) are editable by anyone with
  # incident access. My-schedule rows are only editable by their owner —
  # the UI only shows pencils / trash on your own rows, but we double-
  # check server-side so a hand-crafted request can't tamper with
  # someone else's personal schedule.
  def editable_by_current_user?(schedule)
    return true if schedule.user_id.nil?
    schedule.user_id == current_user&.id
  end

  def ordered_schedules(user_id:)
    @incident.schedules.where(user_id: user_id).reorder(
      Arel.sql("(CASE WHEN NULLIF(time, '') IS NULL THEN 1 ELSE 0 END), time, position, id")
    )
  end

  def schedule_params
    params.require(:schedule).permit(:meeting_name, :time, :location)
  end
end
