class OpsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :load_org_units

  # GET /incidents/:incident_id/ops
  def show
    @tab = params[:tab].in?(%w[ics_215 projections]) ? params[:tab] : 'ics_215'
    @selected_org_unit = @org_units.find_by(id: params[:org_unit_id]) || @org_units.first
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
    end
  end

  # GET /incidents/:incident_id/ops/to_pdf
  # Renders the current tab (215 or projections) for the current branch /
  # division / group selection as a PDF via Grover. Query string mirrors
  # the show action (tab, org_unit_id) so the button URL can be built from
  # the same params.
  def to_pdf
    @tab = params[:tab].in?(%w[ics_215 projections]) ? params[:tab] : 'ics_215'
    @selected_org_unit = @org_units.find_by(id: params[:org_unit_id]) || @org_units.first
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
    @org_units = @incident.org_units
                          .where(kind: [OrgUnit.kinds[:branch],
                                        OrgUnit.kinds[:division],
                                        OrgUnit.kinds[:group]])
                          .order(:kind, :name)
  end

  # A branch expands to its direct D/G children; anything else is itself.
  def branch_children(unit)
    return [unit] unless unit.kind_branch?
    unit.children
        .where(kind: [OrgUnit.kinds[:division], OrgUnit.kinds[:group]])
        .order(:kind, :name)
  end

  # Day 1 = ops_period_from of the latest plan's first assignment, else today.
  # Days 2 and 3 are the two days after that.
  def compute_day_range
    plan  = @incident.plans.order(:created_at).last
    from  = plan&.assignments&.detect { |a| a.ops_period_from.present? }&.ops_period_from
    start = (from || Time.current).to_date
    [start, start + 1, start + 2]
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
end
