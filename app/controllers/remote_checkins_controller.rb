# Public, no-login, conversational check-in form. One question per
# screen, state persisted in session so a refresh or back-button doesn't
# nuke the operator's progress. Final submit creates a RemoteCheckin row
# that the Plans section reviews and promotes on the admin queue.
class RemoteCheckinsController < ApplicationController
  include SkipAuthorization
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: [:restart]
  before_action :set_incident_from_token

  layout 'guest'

  def new
    load_state
    step = RemoteCheckinStepPlan.current_step(@state)
    if step.nil?
      # Walked off the end — final review page.
      @summary = state_summary(@state)
      render :review
    else
      @step  = step
      @index = @state['step_index'].to_i
      @total = RemoteCheckinStepPlan.total_visible(@state)
      render :new
    end
  end

  def update
    load_state

    if params[:commit_submission] == '1'
      finalize_submission
      return
    end

    step = RemoteCheckinStepPlan.current_step(@state)
    if step.nil?
      redirect_to remote_checkin_path(@incident.remote_checkin_token) and return
    end

    answer = params[:answer]

    # Required check — empty-string counts as missing. For yes/no the
    # value arrives as "true"/"false"; a missing one means they
    # pressed Next without a choice.
    if step.required? && blank_answer?(step, answer)
      flash.now[:alert] = 'Please answer the question before continuing.'
      @step  = step
      @index = @state['step_index'].to_i
      @total = RemoteCheckinStepPlan.total_visible(@state)
      render :new, status: :unprocessable_entity and return
    end

    apply_answer(step, answer)

    # Special-case: after the req_number step, look up the request on
    # this incident so the confirmation step and the resource-name
    # auto-fill have something to show.
    resolve_request_match if step.key == 'req_number_raw'

    # Confirmation step: "YES" means pre-fill name from the matched
    # request and skip the plain name question later.
    if step.key == 'confirm_match' && answer == 'true' && @state['matched_request_name'].present?
      @state['name'] = @state['matched_request_name']
    end

    advance_step
    save_state
    redirect_to remote_checkin_path(@incident.remote_checkin_token)
  end

  def back
    load_state
    @state['step_index'] = [@state['step_index'].to_i - 1, 0].max
    save_state
    redirect_to remote_checkin_path(@incident.remote_checkin_token)
  end

  def restart
    reset_state
    redirect_to remote_checkin_path(@incident.remote_checkin_token)
  end

  def thanks
    @submission_name = session[:remote_checkin_last_name]
  end

  private

  def set_incident_from_token
    @incident = Incident.find_by(remote_checkin_token: params[:token])
    unless @incident
      render plain: 'This check-in link is invalid or has been rotated. Please contact the Plans section for a new link.',
             status: :not_found
    end
  end

  def session_key
    "remote_checkin_#{@incident.id}".to_sym
  end

  def load_state
    @state = session[session_key] || default_state
  end

  def save_state
    session[session_key] = @state
  end

  def default_state
    { 'step_index' => 0, 'from_other_incident' => nil }
  end

  def reset_state
    session.delete(session_key)
  end

  def advance_step
    @state['step_index'] = @state['step_index'].to_i + 1
  end

  def blank_answer?(step, answer)
    case step.kind
    when :yes_no then answer.blank? || !%w[true false].include?(answer)
    else answer.to_s.strip.empty?
    end
  end

  # Writes `answer` into the state slot named by step.key, with any
  # per-kind coercion. Dates and integers get normalized here so the
  # final RemoteCheckin.create! doesn't choke on raw strings.
  def apply_answer(step, answer)
    val =
      case step.kind
      when :yes_no    then answer == 'true'
      when :integer   then answer.to_s.strip.presence&.to_i
      when :date
        begin
          answer.to_s.strip.presence && Date.parse(answer)
        rescue ArgumentError
          nil
        end
      when :req_number
        answer.to_s.strip.upcase.gsub(/\s+/, '')
      else
        answer.to_s.strip
      end
    @state[step.key] = val
  end

  # Match the typed req_number against this incident's Request rows,
  # normalizing to "C-3"-style on both sides. Stores the matched id so
  # it survives into the final RemoteCheckin row, and the display name
  # so the confirmation step can ask "Resource Name. Is this you?"
  def resolve_request_match
    raw = @state['req_number_raw'].to_s
    normalized =
      if raw =~ /\A([CEOA])-?(\d+(?:\.\d+)?)\z/
        "#{$1}-#{$2}"
      else
        raw
      end
    @state['req_number_raw'] = normalized

    req = @incident.requests.find_by(req_number: normalized)
    @state['matched_request_id'] = req&.id

    if req
      # Only prefer the auto-match when the request has a resource name
      # on file (filled / checked-in in IROC). An empty requests gives
      # nothing useful to confirm.
      proposed = req.suggested_resource_name.presence
      @state['matched_request_name'] = proposed if proposed
      # Carry category derived from the matched request even if the
      # resource mistyped the prefix.
      @state['category'] = req.resource_category.to_s
    else
      # Fall back to prefix-derived category so the form can still
      # branch (crew vs overhead questions etc).
      @state['category'] = RemoteCheckin.category_for(normalized)
    end
  end

  # Build a user-facing review summary from the collected state.
  def state_summary(state)
    fields = %w[
      req_number_raw category name position agency agency_address email
      overhead_single_resource leader phone emergency_contact mobilization_date
      number_personnel other_crew_members from_other_incident
      other_incident_name other_incident_req_number first_day_worked
      first_work_day demob_city demob_state transportation_method
    ]
    fields.map { |f| [f, state[f]] }.reject { |_, v| v.nil? || v == '' }
  end

  def finalize_submission
    rc = @incident.remote_checkins.new(
      req_number_raw:          @state['req_number_raw'],
      request_id:              @state['matched_request_id'],
      category:                @state['category'],
      name:                    @state['name'],
      position:                @state['position'],
      agency:                  @state['agency'],
      agency_address:          @state['agency_address'],
      email:                   @state['email'],
      leader:                  @state['leader'],
      phone:                   @state['phone'],
      emergency_contact:       @state['emergency_contact'],
      mobilization_date:       @state['mobilization_date'],
      from_other_incident:     @state['from_other_incident'] == true,
      other_incident_name:     @state['other_incident_name'],
      other_incident_req_number: @state['other_incident_req_number'],
      first_day_worked:        @state['first_day_worked'],
      first_work_day:          @state['first_work_day'],
      demob_city:              @state['demob_city'],
      demob_state:             @state['demob_state'],
      transportation_method:   @state['transportation_method'],
      number_personnel:        overhead_single? ? 1 : @state['number_personnel'],
      overhead_single_resource: @state['overhead_single_resource'],
      other_crew_members:      overhead_single? ? nil : @state['other_crew_members'],
      submitted_at:            Time.current
    )

    # Overhead single resources: leader is self.
    if overhead_single? && rc.leader.blank?
      rc.leader = rc.name
    end

    if rc.save
      session[:remote_checkin_last_name] = rc.name
      reset_state
      redirect_to remote_checkin_thanks_path(@incident.remote_checkin_token)
    else
      flash.now[:alert] = "Could not submit: #{rc.errors.full_messages.to_sentence}"
      @summary = state_summary(@state)
      render :review, status: :unprocessable_entity
    end
  end

  def overhead_single?
    @state['overhead_single_resource'] == true
  end
end
