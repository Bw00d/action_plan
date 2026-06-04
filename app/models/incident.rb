class Incident < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :resources, dependent: :destroy
  has_many :checkins
  has_many :org_units
  has_many :root_org_units, -> { where(parent_id: nil) },
           class_name: 'OrgUnit', dependent: :destroy
  has_many :org_unit_assignments, through: :org_units

  belongs_to :owner, class_name: 'User', foreign_key: 'user_id'
  has_and_belongs_to_many :users  # shared users who can edit

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
end
