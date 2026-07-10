class Incident < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :resources, dependent: :destroy
  has_many :checkins
  has_many :org_units
  has_many :root_org_units, -> { where(parent_id: nil) },
           class_name: 'OrgUnit', dependent: :destroy
  has_many :org_unit_assignments, through: :org_units
  has_many :requests, dependent: :destroy
  has_many :personnel_requests, -> { personnel }, class_name: 'Request'
  has_many :schedules, dependent: :destroy
  has_many :demob_notifications, dependent: :destroy
  has_many :financial_codes, dependent: :destroy

  after_create :seed_default_schedule

  belongs_to :owner, class_name: 'User', foreign_key: 'user_id', optional: true
  has_and_belongs_to_many :users  # shared users who can edit

  validates :iroc_inc_id, uniqueness: true, allow_nil: true

  def section(name)
    org_units.kind_section.find_by(name: name.to_s.titleize)
  end

  def command_unit
    org_units.kind_command.first
  end


  def display_incident_name
    "#{self.name}  –  #{self.incident_type} #{self.number}"
  end

  def wildfire?
    return true if self.incident_type == "Wildfire"
  end

  def total_resources
    total = 0
    self.resources.assigned.each do |r|
      unless r.number_personnel.nil?
        total += r.number_personnel
      end
    end
    total
  end

  # def owner
  #     User.find(self.user_id)
  # end

  private

  def seed_default_schedule
    Schedule.seed_defaults!(self)
  end
end
