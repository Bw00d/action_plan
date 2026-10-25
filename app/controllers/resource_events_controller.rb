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
  # Body: resource_event[kind], plus body OR (leader/fwd/lwd/phone).
  # For kind=rnr: optional with_follow_on=1 + follow_on_days creates a
  # second :work entry starting the day after R&R ends with the resource's
  # current leader + phone.
  #
  # The legacy T-card compose form posts kind=scheduled_swap for new
  # upcoming operators. Shift-refactor: those are :work entries with
  # actual_fwd=nil (unpromoted). Translate on the way in so new rows
  # land as :work.
  def create
    attrs = event_params.to_h
    attrs['kind'] = 'work' if attrs['kind'].to_s == 'scheduled_swap'

    ActiveRecord::Base.transaction do
      @event = @resource.resource_events.new(attrs)
      @event.user = current_user
      raise ActiveRecord::Rollback unless @event.save

      if @event.rnr? && params[:with_follow_on].to_s == '1' && @event.lwd
        follow_days = params[:follow_on_days].to_i
        follow_days = 14 if follow_days < 1
        follow_fwd  = @event.lwd + 1.day
        follow_lwd  = follow_fwd + follow_days - 1
        follow_leader = @resource.leader.presence || @resource.name
        @resource.resource_events.create!(
          kind:   :work,
          user:   current_user,
          leader: follow_leader,
          phone:  @resource.phone,
          fwd:    follow_fwd,
          lwd:    follow_lwd
        )
      end
    end

    if @event&.persisted?
      render_feed
    else
      errors = @event&.errors&.full_messages.presence || ['Save failed']
      render json: { errors: errors }, status: :unprocessable_entity
    end
  end

  # PATCH /resources/:resource_id/events/:id
  # Only editable kinds (comment / scheduled_swap) accept updates.
  # Comments are additionally locked to their original author — the
  # pencil only shows up in the UI for the owner, but we double-check
  # server-side so a hand-crafted request can't rewrite someone else's
  # note. Scheduled swaps stay editable by any user with incident
  # access since they're planning-side data, not personal commentary.
  def update
    unless @event.editable?
      render json: { errors: ['This entry is no longer editable.'] }, status: :forbidden
      return
    end
    if @event.comment? && @event.user_id != current_user.id
      render json: { errors: ['Only the author can edit this comment.'] }, status: :forbidden
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
  # Promotes an unpromoted :work entry to current operator:
  #   1. Compute swap date = incoming entry's PLANNED fwd (not today).
  #      Rationale: SWAP NOW means "execute this scheduled swap";
  #      actuals should match the plan the user entered. If the user
  #      wants a different swap date they edit the scheduled entry
  #      first. Falls back to today only when the entry has no
  #      planned fwd (shouldn't happen under validation).
  #   2. Close out the previously-current :work entry — actual_lwd =
  #      swap_date - 1. Clamped to be no earlier than that entry's
  #      actual_fwd so the window never inverts.
  #   3. Promote THIS :work entry — actual_fwd = swap_date.
  #   4. Mirror leader/phone/assignment_length onto the Resource row
  #      for views that still read these columns.
  #   5. Move the primary-roster star to the incoming leader.
  def swap_now
    # scheduled_swap? is a shim that matches unpromoted :work entries.
    unless @event.scheduled_swap?
      render json: { errors: ['Only upcoming shift entries can be promoted.'] }, status: :unprocessable_entity
      return
    end

    swap_date = @event.fwd || Date.current

    ResourceEvent.transaction do
      # 1. Close out the currently-active :work entry (if any). Cap
      #    the new actual_lwd at the entry's actual_fwd so an early
      #    swap can't produce actual_lwd < actual_fwd.
      current_entry = @resource.resource_events
                               .where(kind: ResourceEvent.kinds[:work])
                               .where.not(actual_fwd: nil)
                               .where(actual_lwd: nil)
                               .first
      if current_entry
        proposed_lwd = swap_date - 1.day
        safe_lwd     = [proposed_lwd, current_entry.actual_fwd].max
        current_entry.update!(actual_lwd: safe_lwd)
      end

      # 2. Promote the incoming entry. Also normalize kind → :work in
      #    case this row was created with the legacy :scheduled_swap
      #    kind (controller translation is per-request; a row written
      #    before the Rails process picked up the translation stays
      #    with the old kind until something touches it).
      promote_attrs = { actual_fwd: swap_date }
      promote_attrs[:kind] = :work unless @event.work?
      @event.update!(promote_attrs)

      # 3. Mirror onto the Resource row for views that still read it.
      new_length = if @event.lwd && @resource.fwd
                     [(@event.lwd - @resource.fwd).to_i + 1, 1].max
                   else
                     @resource.assignment_length.to_i
                   end
      @resource.update!(
        leader:            @event.leader,
        phone:             @event.phone.presence || @resource.phone,
        assignment_length: new_length,
        notes:             @event.body       # may be nil — clears old notes
      )

      # 4. Move the primary-star to the incoming leader.
      incoming = @resource.rosters.active.unpromoted.find { |r| r.name == @event.leader }
      if incoming
        incoming.update!(primary: true)
      else
        @resource.rosters.where(primary: true).update_all(primary: false)
      end
    end

    # JSON instead of plain feed HTML: client needs to patch the modal
    # field displays in place (leader / phone / assignment_length / lwd)
    # without a page reload — so the user keeps looking at the open card
    # and sees the swap take effect.
    @resource.reload
    @resource.resource_events.reload   # drop any association cache from the transaction
    lwd = @resource.last_work_day
    cwe = @resource.current_work_entry
    leader_period = if cwe && cwe.actual_fwd && cwe.lwd
                      "(#{cwe.actual_fwd.strftime('%-m/%-d/%y')} – #{cwe.lwd.strftime('%-m/%-d/%y')})"
                    else
                      ''
                    end
    render json: {
      # formats: [:html] is required — this action responds as JSON, so
      # render_to_string inherits that format and would look for
      # _activity_feed.json.erb (which doesn't exist) and raise
      # MissingTemplate. Same gotcha as the iSuite import summary.
      feed_html:   render_to_string(partial: 'boards/activity_feed',
                                    formats: [:html],
                                    locals:  { resource: @resource, events: @resource.resource_events.newest_first }),
      roster_html: render_to_string(partial: 'boards/roster_list',
                                    formats: [:html],
                                    locals:  { resource: @resource }),
      resource: {
        leader:            @resource.leader.to_s,
        phone:             @resource.phone.to_s,
        fwd:               @resource.fwd&.iso8601,
        assignment_length: @resource.assignment_length.to_i,
        lwd:               lwd.is_a?(Date) ? lwd.strftime('%m/%d/%y') : '',
        notes:             @resource.notes.to_s,
        leader_period:     leader_period
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
