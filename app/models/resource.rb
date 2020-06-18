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

end
