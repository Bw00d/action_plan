module ResourcesHelper
  def tally_resources(resources)
    agencies = [] 
      resources.each do |r| 
        agencies << r.agency 
      end
    agencies.group_by(&:itself).transform_values(&:count)
  end

  def get_agencies(resources)
    resources.map { |r| r.agency }
  end

  def get_resources(resources)
    resources.map { |r| r}
  end

  def get_crews(resources)
    resources.crew.pluck(:position).uniq
  end

  def get_equipment(resources)
    resources.equipment.pluck(:position).uniq
  end

  # def get_overhead(resources)
  #   resources.overhead.pluck(:position).uniq
  # end

  def ordered_resources(resources)
    get_crews(resources) + get_equipment(resources)
  end

end
