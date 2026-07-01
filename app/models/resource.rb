class Resource < ApplicationRecord
  belongs_to :incident
  has_one :demob
  has_one :org_unit_assignment, dependent: :destroy
  has_one :org_unit, through: :org_unit_assignment

  scope :unassigned, lambda {
    left_outer_joins(:org_unit_assignment)
      .where(org_unit_assignments: { id: nil })
  }
  scope :overhead, -> { where(category: 'OVERHEAD') }
  scope :equipment, -> { where(category: 'EQUIPMENT') }
  scope :crew, -> { where(category: 'CREW') }
  scope :aircraft, -> { where(category: 'AIRCRAFT') }
  scope :assigned, -> { where(release_date: nil, r_and_r: false)}
  scope :on_rnr, -> { where(r_and_r: true)}
   validates :name, presence: true
   validates :position, presence: true
   validates :agency, presence: true
   validates :order_number, presence: true
   validates :number_personnel, presence: true
   validates :assignment_length, presence: true
   validates :category, presence: true
   # Prevents manual creation of a Resource whose full_order_number would
   # collide with one already on the incident — otherwise we couldn't rely on
   # the Req# ↔ full_order_number tie to compute check-in status.
   validates :order_number,
             uniqueness: {
               scope:   [:incident_id, :category],
               message: "is already used for a resource of this category on this incident"
             },
             if: -> { incident_id.present? && category.present? && order_number.present? }
 
  after_create :create_demob


  def cat
    case self.category
    when 'OVERHEAD'
      'O-'
    when 'CREW'
      'C-'
    when 'EQUIPMENT'
      'E-'
    when 'AIRCRAFT'
      'A-'
    end
  end

  def last_work_day
    if self.fwd && self.assignment_length
      return self.fwd + self.assignment_length-1.days 
    else
      return " "
    end
  end

  def formatted_fwd
    if self.fwd
     return self.fwd.strftime("%m/%d")
   end
  end
  def formatted_release_date
    if self.release_date
     return self.release_date.strftime("%m/%d")
   end
  end

  def full_order_number
   return "#{self.cat}#{self.order_number}"
  end

  def released?
    return true if self.release_date
  end

  def rnr?
    return true if self.r_and_r
  end

  def create_demob
    Demob.create!(resource_id: self.id)
  end

  def demob
    Demob.where(resource_id: self.id).first
  end


end
