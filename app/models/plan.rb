class Plan < ApplicationRecord
  belongs_to :user
  belongs_to :incident
  has_many :assignments, dependent: :destroy
  has_many :objectives, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_one :commo_plan
  has_one :safety_message
  validates :user_id, presence: true
  has_many :teams
  has_one :cover
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

  def command_staff
    Team.where(plan_id: self.id, staff: "Command")
  end

  def agency_reps
    Team.where(plan_id: self.id, staff: "Agency")
  end

  def plans
    Team.where(plan_id: self.id, staff: "Plans")
  end

  def finance
    Team.where(plan_id: self.id, staff: "Finance")
  end

  def operations
    Team.where(plan_id: self.id, staff: "Operations")
  end

  def logistics
    Team.where(plan_id: self.id, staff: "Logistics")
  end

end
