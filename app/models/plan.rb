class Plan < ApplicationRecord
  belongs_to :user
  belongs_to :incident
  has_many :assignments, dependent: :destroy
  has_many :objectives, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_one :commo_plan
  has_one :safety_message
  validates :user_id, presence: true
  # validates :date, presence: true, uniqueness: true
  validates_uniqueness_of :date, :scope => :incident_id
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
