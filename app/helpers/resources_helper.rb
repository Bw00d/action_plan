module ResourcesHelper
  # Pretty-print a diff cell value on the iSuite import preview. Dates
  # render as MM/DD/YYYY, booleans as Yes/No, and blanks as "—" so the
  # operator can tell an empty field from a missing one.
  def format_diff_value(value)
    case value
    when nil, ''       then content_tag(:span, '—', class: 'ii-blank')
    when true          then 'Yes'
    when false         then 'No'
    when Date, Time    then value.strftime('%m/%d/%Y')
    else                    value.to_s
    end
  end

  # Sort resources by category, then by order_number treated as a natural
  # number so E-2 comes before E-10 and subordinate numbers like E-24.1..3
  # sort by each dotted segment. String column ordering in SQL sorts
  # lexicographically ("1", "10", "102", "2"), which is wrong for these
  # display lists — do it in Ruby instead.
  def natural_order_sort(resources)
    resources.sort_by do |r|
      [r.category.to_s, *r.order_number.to_s.scan(/\d+/).map(&:to_i)]
    end
  end

  # Overhead-style tally: { "AGENCY" => count }.
  def tally_resources(resources)
    totals = Hash.new(0)
    resources.each do |r|
      r.personnel_by_agency.each { |agency, count| totals[agency] += count }
    end
    totals
  end

  def get_agencies(resources)
    resources.map { |r| r.agency }
  end

  def get_resources(resources)
    resources
  end

  def release_resource(resource)
    resource.update_attribute(release_date: resource.demob.actual_release_date)
  end

  # Crew/Equipment-style tally: [resource_count, agency, position, personnel_total]
  # per unique (agency, position). Resources whose subordinates come from
  # multiple agencies contribute one row per agency they cover.
  def tally_assigned_resources(resources)
    buckets = Hash.new { |h, k| h[k] = { resource_ids: Set.new, personnel: 0 } }
    resources.each do |r|
      r.personnel_by_agency.each do |agency, count|
        key = [agency, r.position]
        buckets[key][:resource_ids] << r.id
        buckets[key][:personnel]    += count
      end
    end
    buckets.map do |(agency, position), bucket|
      [bucket[:resource_ids].size, agency, position, bucket[:personnel]]
    end
  end

  # ICS-style pivot table for the Resource Tally tab.
  # Returns:
  #   {
  #     columns: [{ key:, label:, category:, position: (or nil), overhead:? }, ...],
  #     agencies: ["AK", "ANC", ...],   # sorted
  #     rows:     { "AK" => { col_key => {resources:, personnel:} }, ... },
  #     totals:   { col_key => {resources:, personnel:} }
  #   }
  #
  # Columns are discovered from actual data — one per unique
  # (category, position) among CREW/AIRCRAFT/EQUIPMENT, plus a fixed
  # "Overhead Personnel" column (aggregates all OVERHEAD) and a
  # "Total Personnel" column (row-wise sum, no resource count).
  # Pass `on_date:` to project the tally forward — only resources that
  # are expected to still be on the incident on that date are counted.
  # A resource stays included when its LWD is nil / non-date (unknown,
  # keep) or on-or-after the target date, AND when it hasn't already
  # released by then. Used for the 7-day forecast tabs below the main
  # tally.
  def resource_tally_pivot(incident, on_date: nil)
    resources = incident.tally_resources.includes(:rosters)

    if on_date
      resources = resources.select do |r|
        lwd = r.last_work_day
        lwd_ok     = !lwd.is_a?(Date) || lwd >= on_date
        release_ok = r.release_date.nil? || r.release_date > on_date
        lwd_ok && release_ok
      end
    end

    # Discover positions per category. Skip blank positions — those
    # don't have anywhere sensible to bucket.
    positions_by_category = Hash.new { |h, k| h[k] = Set.new }
    resources.each do |r|
      next unless %w[CREW AIRCRAFT EQUIPMENT].include?(r.category)
      positions_by_category[r.category] << r.position if r.position.present?
    end

    # Build column list in a stable order: Crew, Aircraft, Equipment,
    # then Overhead, then Total.
    columns = []
    %w[CREW AIRCRAFT EQUIPMENT].each do |cat|
      positions_by_category[cat].to_a.sort.each do |pos|
        columns << {
          key:      "#{cat}::#{pos}",
          label:    tally_column_label(cat, pos),
          category: cat,
          position: pos
        }
      end
    end
    columns << { key: 'OVERHEAD', label: '# of Overhead', overhead: true }
    columns << { key: 'TOTAL',    label: 'Total Personnel',         total:    true }

    # Discover agencies and initialize empty cells.
    agencies = Set.new
    resources.each do |r|
      r.personnel_by_agency.each_key { |a| agencies << a if a.present? }
    end
    agencies = agencies.to_a.sort

    empty_cell = -> { { resources: 0, personnel: 0 } }
    rows = agencies.each_with_object({}) do |agency, h|
      h[agency] = columns.each_with_object({}) { |c, cells| cells[c[:key]] = empty_cell.call }
    end

    # Fill cells. A resource contributes to a (agency, column) bucket
    # once per agency in its personnel_by_agency map. Overhead resources
    # roll up into the single OVERHEAD column regardless of position.
    resources.each do |r|
      col_key =
        case r.category
        when 'OVERHEAD' then 'OVERHEAD'
        when 'CREW', 'AIRCRAFT', 'EQUIPMENT'
          "#{r.category}::#{r.position}" if r.position.present?
        end
      next unless col_key

      r.personnel_by_agency.each do |agency, count|
        next if agency.blank?
        next unless rows[agency] && rows[agency][col_key]

        # Overhead column shows personnel only, no resource count.
        rows[agency][col_key][:resources] += 1 unless col_key == 'OVERHEAD'
        rows[agency][col_key][:personnel] += count
      end
    end

    # Row-wise Total Personnel — sum every non-Total column's personnel.
    rows.each do |_agency, cells|
      cells['TOTAL'][:personnel] = cells.reject { |k, _| k == 'TOTAL' }
                                        .values.sum { |v| v[:personnel] }
    end

    # Column totals.
    totals = columns.each_with_object({}) { |c, h| h[c[:key]] = empty_cell.call }
    rows.each_value do |cells|
      cells.each do |k, v|
        totals[k][:resources] += v[:resources]
        totals[k][:personnel] += v[:personnel]
      end
    end

    { columns: columns, agencies: agencies, rows: rows, totals: totals }
  end

  # Pretty label for a (category, position) column. e.g.
  #   CREW, "Type 1"       -> "Crew, Type 1"
  #   AIRCRAFT, "Type 3"   -> "Helicopter, Type 3"  (best-effort — for
  #                          non-helicopter aircraft the position string
  #                          is used verbatim)
  #   EQUIPMENT, "Type 6"  -> "Engine, Type 6"      (same caveat)
  def tally_column_label(category, position)
    case category
    when 'CREW'      then "Crew, #{position}"
    when 'AIRCRAFT'  then position
    when 'EQUIPMENT' then position
    else                  position
    end
  end
end
