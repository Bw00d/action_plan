# Declarative step list for the public remote-checkin form. Each step
# has a key (the state slot it writes to), a question, an input kind,
# optional options for radio/select, and a `when:` predicate deciding
# whether to show it given current state. The controller walks the plan
# with the state hash — adding a question is a one-line change here
# instead of a new case in the controller.
#
# State hash keys mirror RemoteCheckin column names, with extras for
# form plumbing (`matched_request_id` once the req_number resolves).
class RemoteCheckinStepPlan
  Step = Struct.new(:key, :question, :kind, :help, :options, :when_predicate, :required,
                    keyword_init: true) do
    def show?(state) = when_predicate.nil? || when_predicate.call(state)
    def required?    = required.nil? ? true : required
  end

  # Transportation methods — mirror the enum in the PDF.
  TRANSPORTATION_METHODS = RemoteCheckin::TRANSPORTATION_METHODS

  # Branch predicates — kept at module scope so the step list reads
  # like a form definition instead of lambdas inline everywhere.
  CREW      = ->(s) { s['category'] == 'CREW' }
  OVERHEAD  = ->(s) { s['category'] == 'OVERHEAD' }
  EQUIPMENT = ->(s) { s['category'] == 'EQUIPMENT' }
  AIRCRAFT  = ->(s) { s['category'] == 'AIRCRAFT' }
  OVERHEAD_SINGLE = ->(s) { OVERHEAD.call(s) && s['overhead_single_resource'] == true }
  OVERHEAD_GROUP  = ->(s) { OVERHEAD.call(s) && s['overhead_single_resource'] == false }
  CAME_FROM_OTHER = ->(s) { s['from_other_incident'] == true }
  CAME_FRESH      = ->(s) { s['from_other_incident'] == false }

  # The "Is this you?" confirmation only shows when we matched an
  # existing request AND that request already has a resource name
  # ready to show back (filled or checked-in requests have `res_name`
  # or a `first_name`/`last_name`).
  CONFIRM_MATCH = ->(s) { s['matched_request_name'].present? }

  STEPS = [
    Step.new(key: 'req_number_raw',
             question: 'What is your Request Number?',
             help: 'Format examples: C-3, E-27, O-45. Enter the number you were given on your mobilization order.',
             kind: :req_number,
             required: true),

    # Confirmation shown only when the request resolved to a name.
    Step.new(key: 'confirm_match',
             question: nil, # built in the view from matched_request_name
             kind: :yes_no,
             when_predicate: CONFIRM_MATCH,
             required: true),

    # Name step: CREW uses "Crew Name?"; everyone else "Resource Name?".
    # The confirm step above may auto-populate this when the resource
    # says "yes that's me" — in which case this step is skipped.
    Step.new(key: 'name',
             question: 'Resource Name',
             kind: :text,
             when_predicate: ->(s) { s['name'].blank? && !CREW.call(s) },
             required: true),
    Step.new(key: 'name',
             question: 'Crew Name',
             kind: :text,
             when_predicate: ->(s) { s['name'].blank? && CREW.call(s) },
             required: true),

    Step.new(key: 'position',
             question: 'Position',
             help: 'Examples: ENG6, FFT2, CRWB',
             kind: :text,
             required: true),
    Step.new(key: 'agency',
             question: 'Agency / Organization',
             help: 'Examples: USFS, ODF, Big State Wildfire',
             kind: :text,
             required: true),
    Step.new(key: 'agency_address',
             question: 'Agency / Organization Address',
             kind: :text,
             required: false),
    Step.new(key: 'email',
             question: 'Email',
             kind: :email,
             required: false),

    # OVERHEAD single-resource branch — asked up-front so later steps
    # can skip personnel/leader/other-crew for a single person.
    Step.new(key: 'overhead_single_resource',
             question: 'Are you a single resource?',
             help: "If yes we'll record you as the only person on this request.",
             kind: :yes_no,
             when_predicate: OVERHEAD,
             required: true),

    # Leader — on-incident supervisor.
    Step.new(key: 'leader',
             question: "Leader's name (your supervisor on the incident)",
             kind: :text,
             when_predicate: ->(s) { !OVERHEAD_SINGLE.call(s) },
             required: false),

    Step.new(key: 'phone',
             question: 'Cell number',
             kind: :phone,
             required: false),
    Step.new(key: 'emergency_contact',
             question: 'Emergency contact (name and phone)',
             kind: :text,
             required: false),
    Step.new(key: 'mobilization_date',
             question: 'Mobilization date',
             kind: :date,
             required: false),

    # Personnel count — crews/equipment/overhead-group all need it.
    # Overhead-single is 1 and set automatically on commit.
    Step.new(key: 'number_personnel',
             question: 'Number of personnel (including yourself)',
             kind: :integer,
             when_predicate: ->(s) { !OVERHEAD_SINGLE.call(s) && !AIRCRAFT.call(s) },
             required: false),

    # Names of other crew members — crews, equipment, overhead groups.
    Step.new(key: 'other_crew_members',
             question: 'Names of other crew members',
             help: 'One per line. We use this to seed the roster — a reviewer finalizes it.',
             kind: :textarea,
             when_predicate: ->(s) { !OVERHEAD_SINGLE.call(s) && !AIRCRAFT.call(s) },
             required: false),

    Step.new(key: 'from_other_incident',
             question: 'Did you come from another incident?',
             kind: :yes_no,
             required: true),
    Step.new(key: 'other_incident_name',
             question: 'Previous incident name',
             kind: :text,
             when_predicate: CAME_FROM_OTHER,
             required: false),
    Step.new(key: 'other_incident_req_number',
             question: 'Previous incident request number',
             kind: :text,
             when_predicate: CAME_FROM_OTHER,
             required: false),
    Step.new(key: 'first_day_worked',
             question: 'First day worked on the previous incident',
             kind: :date,
             when_predicate: CAME_FROM_OTHER,
             required: false),
    Step.new(key: 'first_work_day',
             question: 'What will be your first work day on this incident?',
             kind: :date,
             when_predicate: CAME_FRESH,
             required: false),

    Step.new(key: 'demob_city',
             question: 'Demob city (where you go home after this incident)',
             kind: :text,
             required: false),
    Step.new(key: 'demob_state',
             question: 'Demob state',
             kind: :text,
             required: false),
    Step.new(key: 'transportation_method',
             question: 'Transportation method',
             kind: :select,
             options: TRANSPORTATION_METHODS,
             required: false)
  ].freeze

  def self.visible_steps(state)
    STEPS.select { |s| s.show?(state) }
  end

  def self.current_step(state)
    idx = state['step_index'].to_i
    visible_steps(state)[idx]
  end

  def self.total_visible(state)
    visible_steps(state).size
  end
end
