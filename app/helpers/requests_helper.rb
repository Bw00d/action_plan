module RequestsHelper
  # Split a list of Request rows into parents and children keyed by the
  # parent's req_number. A "subordinate" is any request whose req_number
  # contains a dot (e.g. "E-24.1" belongs to "E-24"). Orphan subordinates
  # whose parent isn't in the list get promoted to top-level so they still
  # render.
  #
  # Returns [parents, children_by_parent_number]
  def group_requests_by_parent(rows)
    parents = []
    children = Hash.new { |h, k| h[k] = [] }

    rows.each do |r|
      if subordinate_request?(r.req_number)
        children[parent_req_number(r.req_number)] << r
      else
        parents << r
      end
    end

    parent_numbers = parents.map(&:req_number).to_set
    children.keys.reject { |k| parent_numbers.include?(k) }.each do |orphan_key|
      parents.concat(children.delete(orphan_key))
    end

    [parents, children]
  end

  def subordinate_request?(req_number)
    req_number.to_s.include?('.')
  end

  # "E-24.1" → "E-24"; "E-24.1.2" → "E-24.1"
  def parent_req_number(req_number)
    req_number.to_s.sub(/\.[^.]+\z/, '')
  end
end
