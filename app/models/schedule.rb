class Schedule < ApplicationRecord
  belongs_to :incident

  # Planning-P meeting sequence used when a schedule is first set up for an
  # incident. Order matches the position column so the UI can render them
  # top-to-bottom without extra sorting.
  DEFAULT_MEETINGS = [
    'Operations Briefing',
    'Objectives Meeting',
    'Command & General Staff Meeting',
    'Tactics Preparation',
    'Tactics Meeting',
    'Execute & Assess',
    'Prep for Planning',
    'Planning Meeting',
    'IAP Prep'
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

  # Idempotently seed the default set of meetings for an incident (time and
  # location blank). Existing meeting rows are untouched; missing ones get
  # added at their canonical position.
  def self.seed_defaults!(incident)
    DEFAULT_MEETINGS.each_with_index do |name, i|
      next if incident.schedules.exists?(meeting_name: name)
      incident.schedules.create!(meeting_name: name, position: i + 1)
    end
  end
end
