class PlanningController < ApplicationController
  include SkipAuthorization

  before_action :set_incident

  # GET /incidents/:incident_id/planning
  def show
    @result = nil
  end

  # POST /incidents/:incident_id/planning/reconcile_iroc
  # Body: iroc_csv (file upload)
  #
  # Renders the Planning dashboard directly with the result in @result
  # instead of PRG-ing through flash. A long missing-resources list is
  # too big for the 4KB flash cookie (ActionDispatch::Cookies::
  # CookieOverflow), and there's no real reason to redirect here —
  # the user won't bookmark or refresh this response.
  def reconcile_iroc
    if params[:iroc_csv].blank?
      redirect_to incident_planning_path(@incident),
                  alert: 'Pick an IROC CSV to upload first.'
      return
    end

    csv_io  = params[:iroc_csv].tempfile
    @result = IrocReconciler.new(csv_io).reconcile(@incident)
    render :show
  rescue => e
    Rails.logger.error "IROC reconcile failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    redirect_to incident_planning_path(@incident),
                alert: "Couldn't parse that CSV: #{e.message}"
  end

  # GET /incidents/:incident_id/planning/crew_swaps(.csv)
  # Historical log of every scheduled + completed crew swap on this
  # incident. One row per ResourceEvent. Sortable spreadsheet-style
  # table for Plans Section review of swap activity over the life of
  # the incident. Also responds to .csv for download.
  def crew_swaps
    @swap_events = load_sorted_swap_events

    respond_to do |format|
      format.html
      format.csv do
        stamp    = Time.current.strftime('%Y%m%d_%H%M')
        filename = "crew_swaps_#{@incident.id}_#{stamp}.csv"
        send_data crew_swaps_csv(@swap_events),
                  filename:    filename,
                  type:        'text/csv',
                  disposition: 'attachment'
      end
    end
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  # Pull all swap events across every resource on the incident in a
  # single query so the view doesn't N+1 per resource. Then sort by
  # (resource category, order_number natural, FWD, created_at).
  def load_sorted_swap_events
    events = ResourceEvent
      .joins(:resource)
      .where(resources: { incident_id: @incident.id })
      .where(kind: [ResourceEvent.kinds[:scheduled_swap],
                    ResourceEvent.kinds[:completed_swap]])
      .includes(:resource, :user)
      .to_a

    events.sort_by do |ev|
      r = ev.resource
      [
        r.category.to_s,
        *r.order_number.to_s.scan(/\d+/).map(&:to_i),
        ev.fwd || Date.new(9999, 12, 31),
        ev.created_at
      ]
    end
  end

  # Flat CSV of the crew-swap log — opens cleanly in Excel / Numbers /
  # Sheets. Column shape matches the HTML table on crew_swaps.html.erb.
  def crew_swaps_csv(events)
    require 'csv'
    CSV.generate do |out|
      out << ['Resource', 'Name', 'Status', 'Leader', 'FWD', 'LWD',
              'Phone', 'Notes', 'Logged by', 'Logged at']
      events.each do |ev|
        r = ev.resource
        out << [
          r.full_order_number,
          r.name,
          ev.scheduled_swap? ? 'Scheduled' : 'Completed',
          ev.leader,
          ev.fwd&.strftime('%m/%d/%y'),
          ev.lwd&.strftime('%m/%d/%y'),
          ev.phone,
          ev.body.to_s.gsub(/\r?\n+/, ' / '),   # flatten multi-line notes for CSV
          ev.user&.full_name.presence || ev.user&.email&.split('@')&.first,
          ev.created_at.strftime('%Y-%m-%d %H:%M')
        ]
      end
    end
  end
end
