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
