class OpsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :load_org_units

  # GET /incidents/:incident_id/ops
  def show
    @tab = params[:tab].in?(%w[ics_215 projections]) ? params[:tab] : 'ics_215'
    # @org_units is an Array (section + branches/D/G), so use Array#find
    # rather than AR's find_by.
    @selected_org_unit = @org_units.find { |u| u.id.to_s == params[:org_unit_id].to_s } ||
                         @org_units.first
    return unless @selected_org_unit

    @days = compute_day_range
    # Expand a Branch selection into its Division/Group children so both
    # tabs render one section per D/G under the branch. A D/G selection
    # is a single-section list.
    @display_units = branch_children(@selected_org_unit)

    if @tab == 'ics_215'
      # Datalist suggestions for the "add kind/type" input — every position
      # already in use by resources on this incident.
      @position_suggestions = @incident.resources.assigned
                                       .pluck(:position).compact.uniq.sort
      @sections = @display_units.map { |u| { unit: u, rows: build_215_rows(u) } }
    else
      @sections = @display_units.map do |u|
        { unit:           u,
          rows:           build_projection_rows(u),
          day_personnel:  compute_day_personnel_totals(u) }
      end
      @operations_total_per_day = compute_grand_total_per_day(@sections, @days)
    end
  end

  # GET /incidents/:incident_id/ops/to_pdf
  # Renders the current tab (215 or projections) for the current branch /
  # division / group selection as a PDF via Grover. Query string mirrors
  # the show action (tab, org_unit_id) so the button URL can be built from
  # the same params.
  def to_pdf
    @tab = params[:tab].in?(%w[ics_215 projections]) ? params[:tab] : 'ics_215'
    # @org_units is an Array (section + branches/D/G), so use Array#find
    # rather than AR's find_by.
    @selected_org_unit = @org_units.find { |u| u.id.to_s == params[:org_unit_id].to_s } ||
                         @org_units.first
    return head :not_found unless @selected_org_unit

    @days = compute_day_range
    @display_units = branch_children(@selected_org_unit)

    if @tab == 'ics_215'
      @sections = @display_units.map { |u| { unit: u, rows: build_215_rows(u) } }
    else
      @sections = @display_units.map do |u|
        { unit:           u,
          rows:           build_projection_rows(u),
          day_personnel:  compute_day_personnel_totals(u) }
      end
      @operations_total_per_day = compute_grand_total_per_day(@sections, @days)
    end

    Rails.application.routes.default_url_options[:host]     = request.host_with_port
    Rails.application.routes.default_url_options[:protocol] = request.protocol

    html = render_to_string(
      template: 'ops/ops_to_pdf.pdf.erb',
      layout:   'layouts/pdf.html.erb'
    )

    pdf = Grover.new(html,
      display_url:          request.base_url,
      format:               'Letter',
      landscape:            true,
      margin:               { top: '0.4in', right: '0.4in', bottom: '0.4in', left: '0.4in' },
      print_background:     true,
      prefer_css_page_size: true,
      display_header_footer: false
    ).to_pdf

    filename = "ops_#{@tab}_#{@selected_org_unit.name.parameterize}.pdf"
    send_data pdf, filename: filename, type: 'application/pdf', disposition: 'inline'
  end

  # PATCH /incidents/:incident_id/ops/update_line
  # Body: org_unit_id, day (YYYY-MM-DD), position, req
  def update_line
    key = {
      org_unit_id: params[:org_unit_id],
      day:         Date.parse(params[:day]),
      position:    params[:position]
    }
    scope = @incident.ops_215_lines.where(key)

    # Blank input = "unset" → delete any persisted row. A numeric value
    # (including 0) is a real entry and gets saved. 0 is meaningful because
    # it drives a negative Need (surplus) when Have > 0.
    if params[:req].blank?
      scope.destroy_all
    else
      # Race-safe upsert. If two clients (or a duplicated event handler)
      # both hit find_or_initialize_by before either commits, the second
      # save! trips the unique index — catch it and re-find so the second
      # request wins with an UPDATE instead of a 500.
      begin
        line = scope.first_or_initialize
        line.req = params[:req].to_i
        line.save!
      rescue ActiveRecord::RecordNotUnique
        line = scope.first!
        line.update!(req: params[:req].to_i)
      end
    end
    head :ok
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error("update_line failed: #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    render json: { error: "#{e.class}: #{e.message}" }, status: :internal_server_error
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def load_org_units
    branches_dgs = @incident.org_units
                            .where(kind: [OrgUnit.kinds[:branch],
                                          OrgUnit.kinds[:division],
                                          OrgUnit.kinds[:group]])
                            .order(:kind, :name)
    # "Operations" (the section itself) sits at the top of the picker
    # so the user can see every D/G rolled up under Ops in one view.
    ops = @incident.org_units.kind_section.find_by(name: 'Operations')
    @org_units = ([ops].compact + branches_dgs.to_a)
  end

  # Expand the selected picker option into the list of units the
  # projection/215 tabs should render one block for.
  #   Section (Operations) → the section itself + every D/G descendant
  #                          (recursing through nested Branches)
  #   Branch               → direct D/G children
  #   D/G                  → just itself
  def branch_children(unit)
    if unit.kind_section?
      [unit] + collect_dg_descendants(unit)
    elsif unit.kind_branch?
      unit.children
          .where(kind: [OrgUnit.kinds[:division], OrgUnit.kinds[:group]])
          .order(:kind, :name).to_a
    else
      [unit]
    end
  end

  # Walk the tree below `unit` and return every Division + Group leaf
  # regardless of how many Branches sit in between.
  def collect_dg_descendants(unit)
    result = []
    unit.children.order(:kind, :name).each do |child|
      if child.kind_branch?
        result += collect_dg_descendants(child)
      elsif child.kind_division? || child.kind_group?
        result << child
      end
    end
    result
  end

  # Day 1 = today; subsequent days extend forward based on the user's
  # `days` picker (3–14, default 3). 215 is a forward-looking planning
  # worksheet, so anchoring on the calendar matches how ops fills it
  # out at the start of a shift.
  DAY_COUNT_CHOICES = [3, 5, 7, 10, 14].freeze
  DEFAULT_DAY_COUNT = 3

  def compute_day_range
    @day_count = coerce_day_count(params[:days])
    start = Time.current.to_date
    (0...@day_count).map { |i| start + i }
  end

  def coerce_day_count(raw)
    n = raw.to_i
    DAY_COUNT_CHOICES.include?(n) ? n : DEFAULT_DAY_COUNT
  end

  # Resource is "present" on a given day when it's assigned, not R&R, not
  # released, and its last_work_day (fwd + assignment_length - 1) covers
  # that day inclusive. R&R and released are strong exclusions; missing
  # LWD means we treat the resource as open-ended (still present).
  def resource_present_on?(resource, day)
    return false if resource.release_date.present?
    return false if resource.r_and_r
    lwd = resource.last_work_day
    return true if lwd.is_a?(String)   # fallback: no fwd/length set
    lwd >= day
  end

  def resources_for(unit)
    unit.resources.assigned.to_a
  end

  def build_215_rows(unit)
    resources    = resources_for(unit)
    positions    = resources.map(&:position).compact.uniq
    stored_lines = @incident.ops_215_lines
                            .where(org_unit_id: unit.id, day: @days)
    positions   |= stored_lines.pluck(:position)
    positions    = positions.sort

    positions.map do |position|
      day_data = @days.map do |day|
        have = resources.count { |r| r.position == position && resource_present_on?(r, day) }
        req  = stored_lines.find { |l| l.day == day && l.position == position }&.req
        need = req.nil? ? nil : req - have
        { day: day, have: have, req: req, need: need }
      end
      { position: position, days: day_data }
    end
  end

  def build_projection_rows(unit)
    resources = resources_for(unit)
    positions = resources.map(&:position).compact.uniq.sort

    positions.map do |position|
      per_position = resources.select { |r| r.position == position }
      day_data = @days.map do |day|
        present = per_position.select { |r| resource_present_on?(r, day) }
        { day: day, count: present.count, personnel: present.sum { |r| r.number_personnel.to_i } }
      end
      { position: position, days: day_data }
    end
  end

  def compute_day_personnel_totals(unit)
    resources = resources_for(unit)
    @days.map do |day|
      total = resources.select { |r| resource_present_on?(r, day) }
                       .sum { |r| r.number_personnel.to_i }
      { day: day, total: total }
    end
  end

  # Sum each section's day_personnel row-wise across all displayed
  # sections — gives the "Operations Personnel Total" line at the
  # bottom of the Projections tab.
  def compute_grand_total_per_day(sections, days)
    days.map do |day|
      total = sections.sum do |s|
        cell = s[:day_personnel].find { |dp| dp[:day] == day }
        cell ? cell[:total].to_i : 0
      end
      { day: day, total: total }
    end
  end
end
