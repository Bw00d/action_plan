class Assignment < ApplicationRecord
  belongs_to :plan
  # has_many :commo_items, through: :freqs
  # has_many :freqs

  def freqs
    items = []
    if self.commo_item_ids
      self.commo_item_ids.each { |i| items << CommoItem.find(i) }
    end
    items
  end

  def assigned_resources
    items = []
    if self.resource_ids
      self.resource_ids.each { |i| items << Resource.find(i) }
    end
    items
  end

  def personnel  # this counts assignment personnel
    num_personnel = 0

    if self.resource_ids
      self.resource_ids.each { |r| num_personnel += Resource.find(r).number_personnel } 
    end
    num_personnel
  end

  def operations_resources
    items = []
    if self.ops_personnel_ids
      self.ops_personnel_ids.each { |i| items << Team.find(i) }
    end
    items
  end

  def update_resources(id)
    if self.ops_personnel_ids.include?(id)
      arr = self.ops_personnel_ids.reject{|e| e == id}
      self.update_attributes(ops_personnel_ids: arr)
    end
    
  end
end
