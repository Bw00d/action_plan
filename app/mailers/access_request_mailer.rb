# :nocov:
class AccessRequestMailer < ApplicationMailer
  # Sent to every site admin when someone submits the Request Access form.
  # Falls back to ISSUE_REPORT_TO when there are no admins yet.
  def new_request(access_request)
    @access_request = access_request
    @review_url     = admin_access_requests_url
    recipients = User.admin.pluck(:email).presence || [IssueReportMailer::REPORT_TO]
    mail to:       recipients,
         reply_to: access_request.email,
         subject:  "[Action Plan] Access request from #{access_request.full_name}"
  end

  # Sent to the requester once an admin approves. raw_token is nil when
  # they already have a working account, in which case they just sign in.
  # Greets them by the name on the request, since an old unconfirmed
  # account may carry a bot's made-up name.
  def approved(access_request, raw_token)
    @access_request = access_request
    @accept_url     = raw_token && accept_invitation_url(invitation_token: raw_token)
    @sign_in_url    = new_user_session_url
    mail to:      access_request.email,
         subject: 'Your Action Plan access has been approved'
  end
end
