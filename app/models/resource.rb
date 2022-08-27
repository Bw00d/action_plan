class Resource < ApplicationRecord
  belongs_to :incident
  scope :overhead, -> { where(category: 'OVERHEAD') }
  scope :equipment, -> { where(category: 'EQUIPMENT') }
  scope :crew, -> { where(category: 'CREW') }
  scope :aircraft, -> { where(category: 'AIRCRAFT') }
  scope :assigned, -> { where(release_date: nil)}
  # before_save :format_release_date
  has_one :demob
  after_create :create_demob

  def format_release_date
    if self.release_date?
      date = Date.strptime(self.release_date, '%m/%d/%Y')
      return date.strftime('%Y-%m-%d')
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

  def create_demob
    Demob.create!(resource_id: self.id)
  end

  def demob
    Demob.where(resource_id: self.id).first
  end

end
