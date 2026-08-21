class Resource < ApplicationRecord
  belongs_to :incident
  has_one :demob
  has_one :org_unit_assignment, dependent: :destroy
  has_one :org_unit, through: :org_unit_assignment
  has_many :rosters, dependent: :destroy

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
   with_options unless: :spacer? do
     validates :name, presence: true
     validates :position, presence: true
     validates :agency, presence: true
     validates :order_number, presence: true
     validates :number_personnel, presence: true
     validates :assignment_length, presence: true
     validates :category, presence: true
   end
   # Prevents manual creation of a Resource whose full_order_number would
   # collide with one already on the incident — otherwise we couldn't rely on
   # the Req# ↔ full_order_number tie to compute check-in status.
   validates :order_number,
             uniqueness: {
               scope:   [:incident_id, :category],
               message: "is already used for a resource of this category on this incident"
             },
             if: -> { incident_id.present? && category.present? && order_number.present? }

  after_create :create_demob, unless: :spacer?

  # Guard against ActiveRecord's stricter date coercion turning
  # "8/20/26" (from the datepicker or a form typo) into year 0026.
  # Any parsed date whose year is below 100 gets bumped by 2000 so it
  # lands in the intended 21st century range.
  %i[fwd checkin_date].each do |attr|
    define_method("#{attr}=") do |value|
      super(value)
      current = self[attr]
      if current.is_a?(Date) && current.year < 100
        self[attr] = Date.new(current.year + 2000, current.month, current.day)
      end
    end
  end


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

  # Breaks the resource's personnel count down by agency. When a roster
  # exists (imported subordinates), each active roster row is one person
  # in its own agency; when no roster exists, the whole crew rolls up
  # under the parent resource's agency using number_personnel.
  def personnel_by_agency
    if rosters.exists?
      rosters.active.unpromoted
             .group_by { |r| r.agency.presence || agency }
             .transform_values(&:count)
    else
      { agency => number_personnel.to_i }
    end
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
