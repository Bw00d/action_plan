class InvitationMailer < ApplicationMailer
  # Sent to someone who has NO User account yet. Includes a link that lets
  # them set their password (and name) and lands them on the incident.
  def invite_new_user(user, incident, inviter, raw_token)
    @user       = user
    @incident   = incident
    @inviter    = inviter
    @accept_url = accept_invitation_url(invitation_token: raw_token)
    mail to: user.email, subject: "You've been invited to \"#{incident.name}\" on Action Plan"
  end

  # Sent to an existing user who was just added to an incident.
  def added_to_incident(user, incident, inviter)
    @user         = user
    @incident     = incident
    @inviter      = inviter
    @incident_url = incident_url(incident)
    mail to: user.email, subject: "You've been added to \"#{incident.name}\" on Action Plan"
  end
end
