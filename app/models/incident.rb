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
  has_many :ops_215_lines, dependent: :destroy

  after_create :seed_default_schedule

  belongs_to :owner, class_name: 'User', foreign_key: 'user_id', optional: true
  has_and_belongs_to_many :users  # shared users who can edit

  validates :iroc_inc_id, uniqueness: true, allow_nil: true

  ASSIGNMENT_STYLES = %w[ics_204_wf ics_204].freeze
  validates :assignment_style, inclusion: { in: ASSIGNMENT_STYLES }

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

  # Sum of active personnel across every assigned resource. Uses
  # personnel_by_agency (which counts live rosters.active.unpromoted)
  # rather than the static number_personnel column, so demobbing a
  # single subordinate drops the total by one — matches what the tally
  # sections above show. Resources with no rosters fall back to
  # number_personnel via personnel_by_agency's default branch.
  def total_resources
    self.resources.assigned.sum do |r|
      r.personnel_by_agency.values.sum
    end
  end

  # def owner
  #     User.find(self.user_id)
  # end

  private

  def seed_default_schedule
    Schedule.seed_defaults!(self)
  end
end
