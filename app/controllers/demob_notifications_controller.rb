class DemobNotificationsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :set_notification, only: [:update, :destroy, :transmit]

  def index
    @pending     = @incident.demob_notifications.pending.order(:actual_release_date, :id)
    @transmitted = @incident.demob_notifications.transmitted.order(transmitted_at: :desc)
  end

  def update
    respond_to do |format|
      if @notification.update(notification_params)
        format.html { redirect_back(fallback_location: incident_demob_notifications_path(@incident)) }
        format.json { respond_with_bip(@notification) }
      else
        format.html { redirect_back(fallback_location: incident_demob_notifications_path(@incident), alert: @notification.errors.full_messages.to_sentence) }
        format.json { respond_with_bip(@notification) }
      end
    end
  end

  def transmit
    @notification.mark_transmitted!
    redirect_to incident_demob_notifications_path(@incident),
                notice: "Marked #{@notification.request_number} #{@notification.name} as transmitted."
  end

  def destroy
    @notification.destroy
    redirect_to incident_demob_notifications_path(@incident),
                notice: "Deleted notification for #{@notification.request_number} #{@notification.name}."
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def set_notification
    @notification = @incident.demob_notifications.find(params[:id])
  end

  def notification_params
    params.require(:demob_notification).permit(
      :request_number, :unit_id, :name,
      :actual_release_date, :actual_release_time,
      :return_travel_method, :demob_city_state,
      :ron, :ron_location,
      :est_arrival_date, :est_arrival_time,
      :remarks
    )
  end
end
