# A position a User holds. Certified quals are entered or verified by an
# admin; self-reported ones come from the user and are shown as such.
# Who may change what is enforced in QualificationPolicy.
class Qualification < ApplicationRecord
  enum status: { qualified: 0, trainee: 1 }
  enum source: { self_reported: 0, certified: 1 }

  belongs_to :user
  belongs_to :position
  belongs_to :certified_by, class_name: 'User', optional: true

  validates :position_id, uniqueness: { scope: :user_id, message: 'is already on this profile' }

  # Qualified before trainee, certified before self-reported, then by code.
  scope :display_order, lambda {
    joins(:position).order(:status, source: :desc).order('positions.code')
  }

  def status_label
    trainee? ? 'Trainee · PTB open' : 'Qualified'
  end

  def certify!(admin)
    update!(source: :certified, certified_by: admin, certified_at: Time.current)
  end
end
