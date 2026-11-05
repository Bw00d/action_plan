# Declarative step list for the public remote-demob form — same shape
# as RemoteCheckinStepPlan. Each step writes to the state slot named by
# its key; `when:` hides a step given current state.
#
# State keys mirror RemoteDemob columns. The :datetime kind writes two
# slots, "<key>_date" and "<key>_time", so the stored values match
# Demob#edd/edt.
class RemoteDemobStepPlan
  Step = Struct.new(:key, :question, :kind, :help, :options, :when_predicate, :required,
                    keyword_init: true) do
    def show?(state) = when_predicate.nil? || when_predicate.call(state)
    def required?    = required.nil? ? true : required
  end

  RON = ->(s) { s['ron'] == true }

  STEPS = [
    Step.new(key: 'req_number_raw',
             question: 'What is your Request Number?',
             help: 'Examples: E-123, O-10, C-14',
             kind: :req_number,
             required: true),
    Step.new(key: 'name',
             question: 'Name',
             kind: :text,
             required: true),
    Step.new(key: 'phone',
             question: 'Phone Number',
             kind: :phone,
             required: true),
    Step.new(key: 'travel_method',
             question: 'Method of Travel',
             kind: :select,
             options: RemoteDemob::TRAVEL_METHODS,
             required: true),
    Step.new(key: 'travel_start',
             question: 'Estimated travel start date/time',
             kind: :datetime,
             required: true),
    Step.new(key: 'destination',
             question: 'What is your final destination City, State?',
             help: 'Example: Fairbanks, AK',
             kind: :text,
             required: true),
    Step.new(key: 'ron',
             question: 'Will you be remaining overnight anywhere enroute?',
             kind: :yes_no,
             required: true),
    Step.new(key: 'ron_location',
             question: 'What is the RON City and State?',
             help: 'Example: Tok, AK',
             kind: :text,
             when_predicate: RON,
             required: true),
    Step.new(key: 'arrival',
             question: 'What date and time do you expect to arrive at your final destination?',
             kind: :datetime,
             required: true)
  ].freeze

  def self.visible_steps(state)
    STEPS.select { |s| s.show?(state) }
  end

  def self.current_step(state)
    visible_steps(state)[state['step_index'].to_i]
  end

  def self.total_visible(state)
    visible_steps(state).size
  end
end
