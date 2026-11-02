# A phone number or email address on a user's profile. Hidden unless the
# user marks it shared; only shared ones are ever sent to the directory.
class ContactMethod < ApplicationRecord
  enum kind: { phone: 0, email: 1 }

  belongs_to :user

  before_validation { self.value = value.to_s.strip }

  validates :kind, presence: true
  validates :value, presence: true, length: { maximum: 120 }
  validates :value, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'is not a valid email' }, if: :email?
  validate :phone_has_enough_digits, if: :phone?
  validates :label, length: { maximum: 30 }

  scope :shared, -> { where(shared: true) }
  scope :ordered, -> { order(:position, :id) }

  # Digits (and a leading +) for tel: and sms: links.
  def dial_string
    value.gsub(/[^\d+]/, '')
  end

  private

  def phone_has_enough_digits
    errors.add(:value, 'needs at least 7 digits') if value.present? && value.gsub(/\D/, '').length < 7
  end
end
