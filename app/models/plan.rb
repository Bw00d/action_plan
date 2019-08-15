class Plan < ApplicationRecord
  belongs_to :user
  belongs_to :incident
  has_many :objectives, dependent: :destroy
  validates :user_id, presence: true
  validates :date, presence: true, uniqueness: true
  after_create :duplicate_objectives

  def duplicate_objectives
    if self.incident.plans.count >= 2
      self.incident.plans[-2].objectives.each do |o|
        obj = o.dup 
        obj.update_attributes(plan_id: self.id)
      end
    end
  end

end
