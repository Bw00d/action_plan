# A position a User holds, as they report it. Users manage their own;
# see QualificationPolicy.
class Qualification < ApplicationRecord
  enum status: { qualified: 0, trainee: 1 }

  belongs_to :user
  belongs_to :position

  validates :position_id, uniqueness: { scope: :user_id, message: 'is already on this profile' }

  # Qualified before trainee, then by code.
  scope :display_order, -> { joins(:position).order(:status).order('positions.code') }

  def status_label
    trainee? ? 'Trainee · PTB open' : 'Qualified'
  end
end
