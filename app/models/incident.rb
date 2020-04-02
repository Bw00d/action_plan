class Incident < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :resources, dependent: :destroy

  def display_incident_name
    "#{self.name}  –  #{self.incident_type} #{self.number}"
  end

  def wildfire?
    return true if self.incident_type == "Wildfire"
  end
end
