# Public, no-login, conversational demob form — the departing-resource
# twin of RemoteCheckinsController. One question per screen, state kept
# in session. After the request number we look the resource up and
# pre-fill every later answer we already know. The final submit creates
# a RemoteDemob row that shows on the Plans page with a DMB button.
#
# Shares the incident's remote_checkin_token, so one public link (and
# one rotate button) covers both forms.
class RemoteDemobsController < ApplicationController
  include SkipAuthorization
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [:restart]
  before_action :set_incident_from_token

  layout 'guest'

  def new
    load_state
    @step = RemoteDemobStepPlan.current_step(@state)
    if @step.nil?
      render :review
    else
      render_step
    end
  end

  def update
    load_state

    if params[:commit_submission] == '1'
      finalize_submission
      return
    end

    step = RemoteDemobStepPlan.current_step(@state)
    redirect_to remote_demob_path(@incident.remote_checkin_token) and return if step.nil?

    answer = params[:answer]
    if step.required? && blank_answer?(step, answer)
      flash.now[:alert] = 'Please answer the question before continuing.'
      @step = step
      render_step(status: :unprocessable_entity) and return
    end

    unless apply_answer(step, answer)
      flash.now[:alert] = 'Please enter a valid date and time.'
      @step = step
      render_step(status: :unprocessable_entity) and return
    end

    prefill_from_matched_resource if step.key == 'req_number_raw'

    @state['step_index'] = @state['step_index'].to_i + 1
    save_state
    redirect_to remote_demob_path(@incident.remote_checkin_token)
  end

  def back
    load_state
    @state['step_index'] = [@state['step_index'].to_i - 1, 0].max
    save_state
    redirect_to remote_demob_path(@incident.remote_checkin_token)
  end

  def restart
    session.delete(session_key)
    redirect_to remote_demob_path(@incident.remote_checkin_token)
  end

  def thanks
    @submission_name = session[:remote_demob_last_name]
  end

  private

  def set_incident_from_token
    @incident = Incident.find_by(remote_checkin_token: params[:token])
    unless @incident
      render plain: 'This demob link is invalid or has been rotated. Please contact the Plans section for a new link.',
             status: :not_found
    end
  end

  def session_key
    "remote_demob_#{@incident.id}".to_sym
  end

  def load_state
    @state = session[session_key] || { 'step_index' => 0 }
  end

  def save_state
    session[session_key] = @state
  end

  def render_step(status: :ok)
    @index = @state['step_index'].to_i
    @total = RemoteDemobStepPlan.total_visible(@state)
    render :new, status: status
  end

  def blank_answer?(step, answer)
    case step.kind
    when :yes_no then !%w[true false].include?(answer)
    else answer.to_s.strip.empty?
    end
  end

  # Writes the answer into state. Returns false when a date/time answer
  # can't be parsed, so the step is asked again.
  def apply_answer(step, answer)
    case step.kind
    when :yes_no
      @state[step.key] = answer == 'true'
    when :req_number
      @state[step.key] = RemoteDemob.normalize_req_number(answer)
    when :datetime
      date, time = split_datetime(answer)
      return false if answer.present? && date.nil?
      @state["#{step.key}_date"] = date&.iso8601
      @state["#{step.key}_time"] = time
    else
      @state[step.key] = answer.to_s.strip
    end
    true
  end

  # "2026-11-05T08:30" (a datetime-local value) → [Date, "0830"].
  def split_datetime(value)
    return [nil, nil] unless value.to_s =~ /\A(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2})/
    [Date.iso8601($1), "#{$2}#{$3}"]
  rescue ArgumentError
    [nil, nil]
  end

  # Look the request number up and fill later answers from what the
  # incident already knows: name and phone from the resource or roster
  # entry, travel plans from an ICS-221 already started for them, and
  # check-in's return city / travel method as a fallback. Only fills
  # blanks — unless the number now points somewhere new, in which case
  # the previous resource's values are replaced.
  def prefill_from_matched_resource
    resource, roster = RemoteDemob.match(@incident, @state['req_number_raw'])
    match_key = [resource&.id, roster&.id].compact.join('/')
    changed = @state['match_key'] != match_key
    @state['match_key']        = match_key
    @state['resource_id']      = resource&.id
    @state['roster_id']        = roster&.id
    @state['matched_label']    = resource && "#{(roster || resource).full_order_number} — #{(roster || resource).name}"
    return unless resource

    demob = roster ? roster.demob : resource.demob
    known = {
      'name'          => (roster || resource).name,
      'phone'         => roster ? nil : resource.phone,
      'travel_method' => known_travel_method(demob, resource),
      'travel_start_date' => demob&.edd&.iso8601,
      'travel_start_time' => demob&.edt.presence,
      'destination'   => demob&.destination.presence ||
                         [resource.return_city, resource.return_state].reject(&:blank?).join(', ').presence,
      'ron_location'  => demob&.ron_location.presence,
      'arrival_date'  => demob&.estimated_arrival_date&.iso8601,
      'arrival_time'  => demob&.eta.presence
    }
    known.each do |key, value|
      next if value.blank?
      @state[key] = value if changed || @state[key].blank?
    end
  end

  def known_travel_method(demob, resource)
    [demob&.travel_method, resource.transportation_method].each do |m|
      code = m.presence_in(RemoteDemob::TRAVEL_METHOD_CODES) ||
             RemoteDemob::TRAVEL_METHODS[m] || RemoteDemob::CHECKIN_TRAVEL_METHODS[m]
      return code if code
    end
    nil
  end

  def finalize_submission
    if RemoteDemobStepPlan.current_step(@state)
      # Submit posted before every question was answered (stale tab).
      redirect_to remote_demob_path(@incident.remote_checkin_token) and return
    end

    # Re-match rather than trusting ids carried in the session cookie.
    resource, roster = RemoteDemob.match(@incident, @state['req_number_raw'])
    ron = @state['ron'] == true
    submission = @incident.remote_demobs.new(
      req_number_raw:    @state['req_number_raw'],
      resource:          resource,
      roster:            roster,
      name:              @state['name'],
      phone:             @state['phone'],
      travel_method:     @state['travel_method'],
      travel_start_date: @state['travel_start_date'],
      travel_start_time: @state['travel_start_time'],
      destination:       @state['destination'],
      ron:               ron,
      ron_location:      ron ? @state['ron_location'] : nil,
      arrival_date:      @state['arrival_date'],
      arrival_time:      @state['arrival_time'],
      submitted_at:      Time.current
    )

    if submission.save
      session[:remote_demob_last_name] = submission.name
      session.delete(session_key)
      redirect_to remote_demob_thanks_path(@incident.remote_checkin_token)
    else
      flash.now[:alert] = "Could not submit: #{submission.errors.full_messages.to_sentence}"
      render :review, status: :unprocessable_entity
    end
  end
end
