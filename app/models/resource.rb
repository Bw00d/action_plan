class Resource < ApplicationRecord

  scope :overhead, -> { where(category: 'OVERHEAD') }
  scope :equipment, -> { where(category: 'EQUIPMENT') }
  scope :crew, -> { where(category: 'CREW') }
  scope :aircraft, -> { where(category: 'AIRCRAFT') }

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

  def formatted_date
    if self.fwd
     return self.fwd.strftime("%m/%d/%Y")
   end
  end

  def full_order_number
   return "#{self.cat}#{self.order_number}"
  end

end
