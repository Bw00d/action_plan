class DemobNotificationsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :set_notification, only: [:update, :destroy, :transmit]

  # Fixed order so dispatcher-facing groups always render the same way,
  # with "OTHER" collecting anything unexpected (nil / SUPPLIES / etc.).
  CATEGORY_ORDER = %w[AIRCRAFT CREW EQUIPMENT OVERHEAD].freeze

  def index
    pending_scope = @incident.demob_notifications.pending
                              .includes(:resource)
                              .order(:actual_release_date, :id)
    @pending     = pending_scope.to_a
    @transmitted = @incident.demob_notifications.transmitted.order(transmitted_at: :desc)

    # Group by the parent resource's category so a single page can
    # print or export JUST one dispatcher-facing bucket at a time.
    grouped = @pending.group_by { |n| n.resource&.category.to_s.upcase.presence || 'OTHER' }
    @pending_by_category = CATEGORY_ORDER.each_with_object({}) do |cat, h|
      rows = grouped.delete(cat)
      h[cat] = rows if rows.present?
    end
    # Anything that wasn't in CATEGORY_ORDER falls under OTHER (sorted
    # alphabetically within the bucket so the rendered output is stable).
    unless grouped.empty?
      @pending_by_category['OTHER'] = grouped.values.flatten
                                              .sort_by { |n| n.actual_release_date.to_s }
    end

    respond_to do |format|
      format.html
      format.csv do
        cat     = params[:category].to_s.upcase.presence
        rows    = cat ? @pending_by_category.fetch(cat, []) : @pending
        label   = cat || 'all'
        stamp   = Time.zone.now.strftime('%Y%m%d_%H%M')
        send_data demob_notifications_csv(rows),
                  filename:    "demob_notifications_#{@incident.id}_#{label.downcase}_#{stamp}.csv",
                  type:        'text/csv',
                  disposition: 'attachment'
      end
    end
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

  # Flat CSV matching the on-screen table — opens cleanly in Excel /
  # Numbers / Sheets so a dispatcher can read it without a browser.
  def demob_notifications_csv(rows)
    require 'csv'
    CSV.generate do |out|
      out << ['Request #', 'Unit ID', 'Name',
              'Actual Release Date', 'Actual Release Time',
              'Return Travel Method', 'Demob City/State',
              'RON', 'RON Location',
              'Est Arrival Date', 'Est Arrival Time',
              'Remarks']
      rows.each do |n|
        out << [
          n.request_number, n.unit_id, n.name,
          n.actual_release_date, n.actual_release_time,
          n.return_travel_method, n.demob_city_state,
          n.ron_flag, n.ron_location,
          n.est_arrival_date, n.est_arrival_time,
          n.remarks.to_s.gsub(/\r?\n+/, ' / ')
        ]
      end
    end
  end
end
