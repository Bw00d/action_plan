class Incident < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :resources, dependent: :destroy
  before_save :format_dates

  def format_dates
    format_start_date
    format_containment_date
    format_control_date
    format_out_date
  end

  def format_start_date
    
  end

  def format_containment_date
    
  end

  def format_control_date
    
  end

  def format_out_date
    
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
end
