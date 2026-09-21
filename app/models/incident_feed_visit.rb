# Tracks the last time each user viewed a given incident's Feed page.
# Used by the navbar badge to show a count of new posts since the user's
# last visit. Only IncidentPosts count toward the badge — system events
# are ignored (matches "new posts" wording).
class IncidentFeedVisit < ApplicationRecord
  belongs_to :user
  belongs_to :incident

  # Called from IncidentsController#users to reset the counter after the
  # user opens the feed page.
  def self.mark_seen!(user:, incident:)
    return unless user && incident
    visit = find_or_initialize_by(user_id: user.id, incident_id: incident.id)
    visit.last_seen_at = Time.current
    visit.save!
  rescue ActiveRecord::RecordNotUnique
    # Concurrent request from the same user — retry once and update.
    visit = find_by(user_id: user.id, incident_id: incident.id)
    visit&.update(last_seen_at: Time.current)
  end

  # New-posts count since the user last visited. Own posts don't count
  # (users don't need to be alerted to their own microposts).
  def self.unseen_post_count(user:, incident:)
    return 0 unless user && incident
    scope = incident.posts.where.not(user_id: user.id)
    visit = find_by(user_id: user.id, incident_id: incident.id)
    scope = scope.where("incident_posts.created_at > ?", visit.last_seen_at) if visit
    scope.count
  end
end
