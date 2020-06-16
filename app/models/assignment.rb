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
end
