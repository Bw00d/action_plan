class Incident < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :resources, dependent: :destroy
  has_many :checkins
  has_many :org_units
  has_many :root_org_units, -> { where(parent_id: nil) },
           class_name: 'OrgUnit', dependent: :destroy
  has_many :org_unit_assignments, through: :org_units
  has_many :requests, dependent: :destroy
  has_many :personnel_requests, -> { personnel }, class_name: 'Request'
  has_many :schedules, dependent: :destroy
  has_many :demob_notifications, dependent: :destroy
  has_many :financial_codes, dependent: :destroy
  has_many :ops_215_lines, dependent: :destroy
  has_many :events, -> { order(created_at: :desc) },
                    class_name: 'IncidentEvent', dependent: :destroy
  has_many :posts, class_name: 'IncidentPost', dependent: :destroy

  after_create :seed_default_schedule
  after_create :seed_non_209_bucket
  after_create :seed_default_sections

  # Section org_units (kind=section) auto-seeded on incident creation so
  # the Resource position auto-router has somewhere to drop plans /
  # logistics / finance / operations resources. Names use titleize to
  # match Incident#section lookups.
  DEFAULT_SECTION_NAMES = %w[Plans Logistics Finance Operations].freeze

  # Normalize free-form cost input. Users routinely type formatted numbers
  # like "3,000,000" or "$3,000,000" — ActiveRecord's decimal cast stops
  # at the first non-digit and would silently store 3. Strip commas,
  # dollar signs, and stray whitespace before delegating to super.
  def cost=(value)
    if value.is_a?(String)
      cleaned = value.gsub(/[\s,\$]/, '')
      super(cleaned.presence)
    else
      super
    end
  end

  # Timeline dates on the info panel accept any format an operator is
  # likely to type. Ruby's default Date.parse mishandles US-style short
  # dates ("8/7/26" → 0026-08-07 AD!), so parse explicitly through a set
  # of MM/DD forms first, then fall back to ISO / Date.parse.
  %i[start_date containment_date control_date out_date].each do |field|
    define_method("#{field}=") do |value|
      super(parse_flexible_date(value))
    end
  end

  private

  def parse_flexible_date(value)
    return value if value.blank? || value.is_a?(Date) || value.is_a?(Time)

    s = value.to_s.strip
    return nil if s.empty?

    # Try explicit regex patterns in order. strptime's %Y is greedy and
    # would parse "8/7/26" as year 26 AD, so we can't rely on it.
    parsed =
      case s
      when %r{\A(\d{1,2})/(\d{1,2})/(\d{4})\z}     then build_date($3, $1, $2)  # M/D/YYYY
      when %r{\A(\d{1,2})-(\d{1,2})-(\d{4})\z}     then build_date($3, $1, $2)  # M-D-YYYY
      when %r{\A(\d{1,2})/(\d{1,2})/(\d{2})\z}     then build_date(expand_two_digit_year($3), $1, $2)
      when %r{\A(\d{1,2})-(\d{1,2})-(\d{2})\z}     then build_date(expand_two_digit_year($3), $1, $2)
      when %r{\A(\d{4})-(\d{1,2})-(\d{1,2})\z}     then build_date($1, $2, $3)  # ISO
      end

    return parsed if parsed

    # Last resort — let Date.parse have a go for anything unusual. Falls
    # back to the raw value so ActiveRecord surfaces its own error rather
    # than silently blanking the field.
    Date.parse(s) rescue value
  end

  # POSIX pivot: 00–68 → 2000–2068, 69–99 → 1969–1999. Matches strptime's
  # %y behavior and everyone's mental model of "what year is 26?".
  def expand_two_digit_year(yy)
    n = yy.to_i
    n + (n < 70 ? 2000 : 1900)
  end

  def build_date(y, m, d)
    Date.new(y.to_i, m.to_i, d.to_i)
  rescue ArgumentError
    nil
  end

  public

  # IDs of resources parked in a Non-209 org_unit — these are excluded from
  # the Resource Tally, Glide Path, and ICS-211 (they don't belong on the
  # 209 rollup, hence the name). Returns [] fast when no such column exists.
  def non_209_resource_ids
    non_209_units = org_units.where(kind: OrgUnit.kinds[:non_209])
    return [] if non_209_units.empty?

    OrgUnitAssignment.where(org_unit_id: non_209_units.select(:id))
                     .pluck(:resource_id)
  end

  # Resources.assigned minus the Non-209 bucket. Use anywhere the tally /
  # 211 / glide-path show resources.
  def tally_resources
    ids = non_209_resource_ids
    scope = resources.assigned
    scope = scope.where.not(id: ids) if ids.any?
    scope
  end

  # Record a single audit-log entry for this incident. Rescue rather than
  # raise so a logging failure never blocks the real action (e.g. plan
  # creation succeeds even if event write hits a DB hiccup). Kind is
  # a short machine-readable identifier; message is the rendered string
  # users see on the collaborators page.
  def log_event(kind:, message:, user: nil, details: {})
    events.create!(kind: kind, message: message, user: user, details: details)
  rescue => e
    Rails.logger.warn "Incident##{id} log_event(#{kind}) failed: #{e.class}: #{e.message}"
    nil
  end

  belongs_to :owner, class_name: 'User', foreign_key: 'user_id', optional: true
  has_and_belongs_to_many :users  # shared users who can edit

  validates :iroc_inc_id, uniqueness: true, allow_nil: true

  ASSIGNMENT_STYLES = %w[ics_204_wf ics_204].freeze
  validates :assignment_style, inclusion: { in: ASSIGNMENT_STYLES }

  def section(name)
    org_units.kind_section.find_by(name: name.to_s.titleize)
  end

  def command_unit
    org_units.kind_command.first
  end


  def display_incident_name
    "#{self.name}  –  #{self.incident_type} #{self.number}"
  end

  def wildfire?
    return true if self.incident_type == "Wildfire"
  end

  # Sum of active personnel across every assigned resource. Uses
  # personnel_by_agency (which counts live rosters.active.unpromoted)
  # rather than the static number_personnel column, so demobbing a
  # single subordinate drops the total by one — matches what the tally
  # sections above show. Resources with no rosters fall back to
  # number_personnel via personnel_by_agency's default branch.
  def total_resources
    self.resources.assigned.sum do |r|
      r.personnel_by_agency.values.sum
    end
  end

  # def owner
  #     User.find(self.user_id)
  # end

  private

  def seed_default_schedule
    Schedule.seed_defaults!(self)
  end

  def seed_non_209_bucket
    return if org_units.where(kind: OrgUnit.kinds[:non_209]).exists?
    org_units.create!(kind: :non_209, name: 'Non-209', parent_id: nil)
  end

  # Create the standard section org units (Plans / Logistics / Finance /
  # Operations) and the Command unit if missing, idempotently. Lets the
  # Resource auto-router drop position-matched resources onto them from
  # day one.
  def seed_default_sections
    DEFAULT_SECTION_NAMES.each do |name|
      next if org_units.kind_section.where(name: name).exists?
      org_units.create!(kind: :section, name: name, parent_id: nil)
    end
    unless org_units.kind_command.exists?
      org_units.create!(kind: :command, name: 'Command', parent_id: nil)
    end
  rescue => e
    Rails.logger.warn "Incident##{id} seed_default_sections failed: #{e.class}: #{e.message}"
  end
end
