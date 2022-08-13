class Resource < ApplicationRecord
  belongs_to :incident, dependent: :destroy
  scope :overhead, -> { where(category: 'OVERHEAD') }
  scope :equipment, -> { where(category: 'EQUIPMENT') }
  scope :crew, -> { where(category: 'CREW') }
  scope :aircraft, -> { where(category: 'AIRCRAFT') }
  scope :assigned, -> { where(release_date: nil)}

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
      return self.fwd + self.assignment_length.days
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

end
