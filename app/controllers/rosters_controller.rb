class RostersController < ApplicationController
  include SkipAuthorization

  before_action :set_roster, only: [:promote, :new_demob, :demob]

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

  # GET /rosters/:id/new_demob
  # Renders a compact demob-notification form prefilled with this roster
  # entry's info. Submitting it hits #demob below.
  def new_demob
    @incident = @roster.resource.incident
    @notification = @incident.demob_notifications.new(
      resource: @roster.resource,
      roster:   @roster,
      **@roster.demob_prefill
    )
  end

  # POST /rosters/:id/demob
  # Creates a DemobNotification for this roster entry AND flips the
  # roster's released_at so the parent's personnel count drops by one.
  # Wrapped in a transaction so a validation failure on the notification
  # doesn't leave the roster half-released.
  def demob
    incident = @roster.resource.incident
    @notification = incident.demob_notifications.new(demob_notification_params)
    @notification.resource = @roster.resource
    @notification.roster   = @roster
    release_at = parsed_release_at(@notification)

    ActiveRecord::Base.transaction do
      @notification.save!
      @roster.release!(at: release_at)
    end

    redirect_to incident_demob_notifications_path(incident),
                notice: "Demob notification created for #{@notification.name}. Removed from #{@roster.resource.full_order_number} personnel count."
  rescue ActiveRecord::RecordInvalid => e
    @incident = incident
    flash.now[:alert] = "Could not demob: #{e.message}"
    render :new_demob, status: :unprocessable_entity
  end

  private

  def set_roster
    @roster = Roster.find(params[:id])
  end

  def demob_notification_params
    params.require(:demob_notification).permit(
      :request_number, :unit_id, :name,
      :actual_release_date, :actual_release_time,
      :return_travel_method, :demob_city_state,
      :ron, :ron_location,
      :est_arrival_date, :est_arrival_time,
      :remarks
    )
  end

  # Timestamp the roster with the actual release date at midnight in the
  # app timezone. Falls back to Time.current if the user didn't provide a
  # date (form validation should prevent this but be defensive).
  def parsed_release_at(notification)
    date = notification.actual_release_date
    return Time.current unless date.is_a?(Date)
    Time.zone.local(date.year, date.month, date.day)
  end
end
