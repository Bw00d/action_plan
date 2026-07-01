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

  # Determines a Request's status from the matched Resource (if any).
  # Returns :filled (no resource), :checked_in (resource, no release_date),
  # :released (resource with a release_date), or nil for un-checkinable rows
  # (Supply) and subordinates (whose orders can't cleanly tie to a Resource
  # given integer order_numbers).
  def request_status(request, resources_by_order)
    return nil unless request.checkinable?
    return nil if request.subordinate?

    resource = resources_by_order[request.req_number]
    return :filled unless resource
    return :released if resource.release_date.present?
    :checked_in
  end

  def request_status_label(status)
    { filled: 'F', checked_in: 'C', released: 'D' }[status]
  end

  def request_status_title(status)
    { filled: 'Filled', checked_in: 'Checked In', released: 'Demobed' }[status]
  end
end
