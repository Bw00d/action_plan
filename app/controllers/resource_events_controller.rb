class ResourceEventsController < ApplicationController
  # Same access pattern as the other board-related controllers — users
  # with incident access can edit the activity feed. Pundit is skipped
  # since we already resolve through the resource.
  include SkipAuthorization

  before_action :set_resource
  before_action :set_event, only: [:update, :destroy, :swap_now]

  # GET /resources/:resource_id/events
  # Returns the rendered activity feed as HTML — called after each
  # create/update/destroy so the modal panel re-paints inline.
  def index
    @events = @resource.resource_events.newest_first
    render partial: 'boards/activity_feed', locals: { resource: @resource, events: @events }
  end

  # POST /resources/:resource_id/events
  # Body: resource_event[kind], plus body OR (leader/fwd/lwd/phone)
  def create
    @event = @resource.resource_events.new(event_params)
    @event.user = current_user
    if @event.save
      render_feed
    else
      render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /resources/:resource_id/events/:id
  # Only editable kinds (comment / scheduled_swap) accept updates.
  def update
    unless @event.editable?
      render json: { errors: ['This entry is no longer editable.'] }, status: :forbidden
      return
    end
    if @event.update(event_params)
      render_feed
    else
      render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /resources/:resource_id/events/:id
  def destroy
    unless @event.editable?
      render json: { errors: ['This entry is no longer deletable.'] }, status: :forbidden
      return
    end
    @event.destroy
    render_feed
  end

  # POST /resources/:resource_id/events/:id/swap_now
  # Executes a scheduled_swap:
  #   1. Capture the OUTGOING operator's data from the Resource.
  #   2. Create a completed_swap event documenting that former operator.
  #   3. Update the Resource with the new operator's leader/fwd/phone,
  #      and back-calculate assignment_length so Resource#last_work_day
  #      returns the user-entered swap LWD.
  #   4. Delete the scheduled_swap row — its contents now live on the
  #      Resource itself + any future completed_swap entries.
  def swap_now
    unless @event.scheduled_swap?
      render json: { errors: ['Only scheduled swaps can be executed.'] }, status: :unprocessable_entity
      return
    end

    ResourceEvent.transaction do
      # 1 + 2: snapshot the outgoing operator.
      outgoing_lwd = (@resource.last_work_day if @resource.last_work_day.is_a?(Date))
      @resource.resource_events.create!(
        kind:   :completed_swap,
        user:   current_user,
        leader: @resource.leader,
        fwd:    @resource.fwd,
        lwd:    outgoing_lwd,
        phone:  @resource.phone,
        body:   "Rotated off"
      )

      # 3: update the Resource. Leader + phone switch to the new operator.
      # The equipment's own FWD is left alone (it's been on the incident
      # since its original check-in). assignment_length is EXTENDED by
      # the new operator's commitment length so Resource#last_work_day
      # (fwd + length - 1) rolls forward to the new LWD without rewriting
      # history.
      added_days = if @event.fwd && @event.lwd
                     ((@event.lwd - @event.fwd).to_i + 1)
                   else
                     0
                   end
      @resource.update!(
        leader:            @event.leader,
        phone:             @event.phone.presence || @resource.phone,
        assignment_length: @resource.assignment_length.to_i + added_days
      )

      # 4: scheduled event is consumed by the swap.
      @event.destroy!
    end

    # JSON instead of plain feed HTML: client needs to patch the modal
    # field displays in place (leader / phone / assignment_length / lwd)
    # without a page reload — so the user keeps looking at the open card
    # and sees the swap take effect.
    @resource.reload
    lwd = @resource.last_work_day
    render json: {
      # formats: [:html] is required — this action responds as JSON, so
      # render_to_string inherits that format and would look for
      # _activity_feed.json.erb (which doesn't exist) and raise
      # MissingTemplate. Same gotcha as the iSuite import summary.
      feed_html: render_to_string(partial: 'boards/activity_feed',
                                  formats: [:html],
                                  locals:  { resource: @resource, events: @resource.resource_events.newest_first }),
      resource: {
        leader:            @resource.leader.to_s,
        phone:             @resource.phone.to_s,
        fwd:               @resource.fwd&.iso8601,
        assignment_length: @resource.assignment_length.to_i,
        lwd:               lwd.is_a?(Date) ? lwd.strftime('%m/%d/%y') : ''
      }
    }
  end

  private

  def set_resource
    @resource = Resource.find(params[:resource_id])
  end

  def set_event
    @event = @resource.resource_events.find(params[:id])
  end

  def event_params
    params.require(:resource_event).permit(:kind, :body, :leader, :fwd, :lwd, :phone)
  end

  def render_feed
    @events = @resource.resource_events.newest_first
    render partial: 'boards/activity_feed',
           locals:  { resource: @resource, events: @events }
  end
end
