# A request for an Action Plan account, submitted from the public Request
# Access form. Site admins approve it (which creates the account and emails
# a set-password link) or decline it. Nothing is ever emailed to the
# requester's address until an admin approves, so bots can't use the form
# to send mail to strangers.
class AccessRequest < ApplicationRecord
  enum status: { pending: 0, approved: 1, declined: 2 }

  belongs_to :reviewed_by, class_name: 'User', optional: true

  before_validation { self.email = email.to_s.strip.downcase }

  validates :first_name, :last_name, :position, presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :no_other_pending_request, on: :create

  scope :recent_first, -> { order(created_at: :desc) }

  def full_name
    [first_name, last_name].join(' ')
  end

  # Creates the account (or finds an existing one) and marks the request
  # approved. Returns [user, raw_token]; raw_token is nil when the person
  # already has a working account. Raises if the account can't be created.
  #
  # An existing but unconfirmed account (often an old bot sign-up) gets a
  # fresh set-password link rather than being confirmed, since whoever
  # created it knows its password. Its name is replaced with the one on
  # the request so the set-up form isn't prefilled with a bot's name.
  def approve!(admin)
    transaction do
      user = User.find_by(email: email)
      raw_token = nil
      if user.nil?
        user, raw_token = User.create_invited(email: email, first_name: first_name, last_name: last_name)
        raise ActiveRecord::RecordInvalid, user unless user.persisted?
      elsif !user.confirmed?
        user.update_columns(first_name: first_name, last_name: last_name)
        raw_token = user.regenerate_invitation_token!
      end
      update!(status: :approved, reviewed_by: admin, reviewed_at: Time.current)
      [user, raw_token]
    end
  end

  def decline!(admin)
    update!(status: :declined, reviewed_by: admin, reviewed_at: Time.current)
  end

  private

  def no_other_pending_request
    return unless AccessRequest.pending.where(email: email).exists?
    errors.add(:email, 'already has a request waiting for review')
  end
end
