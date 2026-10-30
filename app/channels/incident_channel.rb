# Live "someone else changed this incident" notices. Every incident page
# subscribes (channels/incident_changes.js); IncidentChangeNotifier
# broadcasts here when tracked records change. Access mirrors the rest of
# the app: any signed-in user who can open the incident can listen.
class IncidentChannel < ApplicationCable::Channel
  def self.stream_name(incident_id)
    "incident:#{incident_id}:changes"
  end

  def subscribed
    incident = Incident.find_by(id: params[:incident_id])
    return reject unless incident

    stream_from self.class.stream_name(incident.id)
  end
end
