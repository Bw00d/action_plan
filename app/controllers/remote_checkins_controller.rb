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
      # Walked off the end — final review page. Persist a draft
      # RemoteCheckin so best_in_place has a real record to PATCH. The
      # draft is identified by submitted_at IS NULL and excluded from
      # the admin queue; it's finalized when the user clicks Submit.
      @draft = find_or_create_draft
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

    # Confirmation step: "YES" means pre-fill every field we can derive
    # from the matched request — name, position, agency, personnel
    # count, suggested leader — so the resource only has to confirm or
    # correct what we already know, rather than retype it. The resource
    # can still edit any of these on the subsequent steps.
    if step.key == 'confirm_match' && answer == 'true' && @state['matched_request_id'].present?
      prefill_from_matched_request
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

  # best_in_place inline edit on the review page. Scoped by the token
  # (so a draft from another incident can't be addressed), and only
  # permits updates while the row is still a draft (submitted_at nil)
  # — once the resource clicks Submit, the row is frozen for them and
  # the admin queue owns it.
  def update_draft
    load_state
    draft = @incident.remote_checkins.where(submitted_at: nil).find_by(id: params[:id])
    unless draft && @state['draft_id'] == draft.id
      head :not_found and return
    end
    field = params[:field]&.to_sym || detect_field_from_params
    value = params.dig(:remote_checkin, field) || params[field]
    unless RemoteCheckin::EDITABLE_DRAFT_FIELDS.include?(field.to_s)
      head :unprocessable_entity and return
    end
    draft.update!(field => coerce_draft_value(field, value))
    # best_in_place expects the server to echo the new value back as
    # plain text (or JSON). Plain text keeps us compatible with the
    # library's default display_as behavior.
    render plain: draft.public_send(field).to_s
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

  # Called when the resource confirms "Is this you?" with YES on the
  # matched-request step. Pulls every field the Request already knows
  # about into state so later steps show pre-populated with the known
  # value — the resource confirms by hitting Next, or edits if wrong.
  # Mirrors the derivations in RequestCheckinsController#new.
  def prefill_from_matched_request
    req = @incident.requests.find_by(id: @state['matched_request_id'])
    return unless req

    @state['name']     = req.suggested_resource_name.presence || @state['matched_request_name']
    @state['position'] = req.filled_catalog_item_code if @state['position'].blank?
    @state['agency']   = req.res_prov_agency_abbrev   if @state['agency'].blank?

    # Personnel count + leader are derived from subordinate requests the
    # same way RequestCheckinsController does it — a crew/strike-team
    # parent's descendants are the personnel; the first direct sub is
    # the leader. A lone overhead has itself as leader.
    children_map = Request.build_children_map(@incident.requests)
    descendants  = Request.descendants_of(req.req_number, children_map)
    direct_subs  = Request.direct_children_of(req.req_number, children_map)

    if @state['number_personnel'].blank? && descendants.any?
      @state['number_personnel'] = descendants.size
    end

    if @state['leader'].blank?
      @state['leader'] =
        if direct_subs.any?
          direct_subs.first&.suggested_resource_name
        elsif req.resource_category == 'OVERHEAD'
          Resource.format_leader_name(req.suggested_resource_name)
        end
    end
  end


  # Finalize = flip the draft that review's best_in_place has been
  # patching to a submitted row. The draft already holds the right
  # values; we just stamp submitted_at and clean up session state.
  def finalize_submission
    draft = @incident.remote_checkins.where(submitted_at: nil).find_by(id: @state['draft_id'])
    unless draft
      # Session must have been nuked between hitting Review and
      # clicking Submit — start the user over.
      reset_state
      redirect_to remote_checkin_path(@incident.remote_checkin_token),
                  alert: 'Your session expired. Please re-enter your check-in.'
      return
    end

    # Overhead single resources: enforce invariants a form user can't
    # see — personnel=1, leader=self.
    if draft.overhead_single_resource
      draft.number_personnel = 1
      draft.leader = draft.name if draft.leader.blank?
    end
    draft.submitted_at = Time.current

    if draft.save
      session[:remote_checkin_last_name] = draft.name
      reset_state
      redirect_to remote_checkin_thanks_path(@incident.remote_checkin_token)
    else
      flash.now[:alert] = "Could not submit: #{draft.errors.full_messages.to_sentence}"
      @draft = draft
      render :review, status: :unprocessable_entity
    end
  end

  # Build (or re-use) the draft row that mirrors session state. Called
  # on first entry to the review page; later edits via best_in_place
  # update this row directly, so state_summary is no longer the source
  # of truth once the user has reached review.
  def find_or_create_draft
    if @state['draft_id']
      existing = @incident.remote_checkins.where(submitted_at: nil).find_by(id: @state['draft_id'])
      return existing if existing
    end
    draft = @incident.remote_checkins.create!(draft_attributes_from_state)
    @state['draft_id'] = draft.id
    save_state
    draft
  end

  def draft_attributes_from_state
    {
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
      submitted_at:            nil
    }
  end

  def overhead_single?
    @state['overhead_single_resource'] == true
  end

  # best_in_place sends the field key as part of the params hash shape
  # `{ remote_checkin: { phone: '...' } }`. If the field isn't passed
  # explicitly in :field, pick it from whatever single key is nested.
  def detect_field_from_params
    nested = params[:remote_checkin]&.to_unsafe_h || {}
    nested.keys.first&.to_sym
  end

  def coerce_draft_value(field, value)
    case field.to_sym
    when :mobilization_date, :first_day_worked, :first_work_day
      Date.parse(value.to_s) rescue nil
    when :from_other_incident, :overhead_single_resource
      ActiveModel::Type::Boolean.new.cast(value)
    when :number_personnel
      value.to_s.strip.presence&.to_i
    else
      value.to_s
    end
  end
end
