# :nocov:
class ApplicationMailer < ActionMailer::Base
  # From address is env-configurable so the sender matches the Mailgun
  # domain in each deployed environment (sandbox or verified).
  default from: ENV.fetch('MAIL_FROM', 'Action Plan <bwoodreid@gmail.com>')
  layout 'mailer'
end
# :nocov:
