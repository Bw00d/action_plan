# Tells everyone else viewing an incident that its data changed, so they
# know to refresh (see IncidentChannel + channels/incident_changes.js).
#
# Fires from model after_commit hooks via
# ApplicationRecord.broadcasts_incident_changes. One notice per
# [incident, area] per request/job keeps bulk imports from flooding
# sockets. Never raises — a Redis hiccup must not break a save.
class IncidentChangeNotifier
  def self.notify(incident_id, area)
    return if incident_id.blank?

    announced = (Current.announced_changes ||= Set.new)
    key = [incident_id, area]
    return if announced.include?(key)
    announced << key

    user = Current.user
    ActionCable.server.broadcast(
      IncidentChannel.stream_name(incident_id),
      area:      area,
      user_id:   user&.id,
      user_name: user&.full_name.presence || user&.email || 'Someone'
    )
  rescue StandardError => e
    Rails.logger.warn "[IncidentChangeNotifier] #{e.class}: #{e.message}"
  end
end
