class Schedule < ApplicationRecord
  belongs_to :incident
  # user_id nil → shared incident "Meeting Schedule" row.
  # user_id set → private "My Schedule" row owned by that user.
  belongs_to :user, optional: true

  # Planning-P meeting sequence used when a schedule is first set up.
  # Used both for the incident-wide schedule and (same list) for each
  # user's "My Schedule" seed.
  DEFAULT_MEETINGS = [
    'Operations Briefing',
    'Objectives Meeting',
    'Command & General Staff',
    'Tactics Meeting',
    'Planning Meeting'
  ].freeze

  validates :meeting_name, presence: true
  # 24-hour military time, four digits (00-23 hours, 00-59 minutes). Blank
  # is allowed so meetings can be added without a time set yet.
  validates :time,
            format: { with: /\A([01]\d|2[0-3])[0-5]\d\z/,
                      message: "must be 4 digits in 24-hour format (e.g. 0700, 1330)" },
            allow_blank: true

  before_validation :normalize_time

  private

  def normalize_time
    self.time = time.to_s.strip.gsub(/\D/, '') if time.present?
    # Left-pad three-digit entries: "700" → "0700"
    self.time = time.rjust(4, '0') if time.present? && time.length.between?(1, 3)
  end

  public

  default_scope -> { order(:position, :id) }

  # Idempotently seed the default set of meetings for an incident. When
  # user is nil, seeds the shared "Meeting Schedule." When user is set,
  # seeds that user's personal "My Schedule." Existing rows in the given
  # scope are untouched; missing ones get added at their canonical
  # position.
  def self.seed_defaults!(incident, user: nil)
    scope = incident.schedules.where(user_id: user&.id)
    DEFAULT_MEETINGS.each_with_index do |name, i|
      next if scope.exists?(meeting_name: name)
      incident.schedules.create!(
        meeting_name: name,
        position:     i + 1,
        user_id:      user&.id
      )
    end
  end
end
