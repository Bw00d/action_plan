class IncidentEvent < ApplicationRecord
  belongs_to :incident
  belongs_to :user, optional: true

  # Skip Rails' auto-touch on updated_at (there's no updated_at column —
  # events are immutable). Keep created_at as the sortable timestamp.
  self.record_timestamps = false
  before_create { self.created_at ||= Time.current }

  # Human-readable actor. Falls back to a generic "System" for events
  # logged without a user (background jobs, callbacks with no request
  # context). Uses first_name + last_name when both are set; email
  # otherwise.
  def actor_name
    return 'System' unless user
    name = [user.first_name, user.last_name].reject(&:blank?).join(' ')
    name.presence || user.email
  end
end
