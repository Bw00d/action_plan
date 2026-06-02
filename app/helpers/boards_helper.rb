module BoardsHelper
  def column_subtitle(unit)
    ancestors = []
    current = unit.parent
    while current
      ancestors.unshift(current.name)
      current = current.parent
    end
    ancestors.join(' / ').presence
  end
end
