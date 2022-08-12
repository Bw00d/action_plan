class Resource < ApplicationRecord

  def cat
    case self.category
    when 'OVERHEAD'
      'O-'
    when 'CREW'
      'C-'
    when 'EQUIPMENT'
      'E-'
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
