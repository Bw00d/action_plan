class Checkin < ApplicationRecord
  belongs_to :incident

  def full_order_number
    return "#{self.cat}#{self.order_number.drop_decimal}"
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

end
