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
  after_create :duplicate_plan

  def duplicate_plan
    if self.incident.plans.count >= 2
      self.duplicate_objectives
      self.duplicate_teams
      self.duplicate_assignments
      self.duplicate_commo_plan
      self.duplicate_safety_message
    end
  end

  def duplicate_objectives
      self.incident.plans.last(2).first.objectives.each do |o|
        Objective.create(plan_id: self.id, description: o.description, order: o.order)
      end
  end

  def duplicate_teams
    if self.incident.plans.last(2).first.teams
      self.incident.plans.last(2).first.teams.each do |t|
        team = t.dup
        team.update_attributes(plan_id: self.id)
      end
    end
  end

  def duplicate_assignments
    if self.incident.plans.last(2).first.assignments
      self.incident.plans.last(2).first.assignments.each do |a|
        assignment = a.dup
        assignment.update_attributes(plan_id: self.id)
      end
    end
  end

  def duplicate_commo_plan
    if self.incident.plans.last(2).first.commo_plan
      commo_plan = self.incident.plans.last(2).first.commo_plan.dup
      commo_plan.update_attributes(plan_id: self.id)
      self.incident.plans.last(2).first.commo_plan.commo_items.each do |item|
        new_item = item.dup
        new_item.update_attributes(commo_plan_id: commo_plan.id)
      end
    end
  end

  def duplicate_safety_message
    if self.incident.plans.last(2).first.safety_message
       SafetyMessage.create( plan_id: self.id, hazards: self.incident.plans.last(2).first.safety_message.hazards)
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
