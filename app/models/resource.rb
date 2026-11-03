class Resource < ApplicationRecord
  broadcasts_incident_changes 'resources'
  belongs_to :incident
  has_one :demob

  # The directory user who filled this assignment (overhead only). Set
  # automatically when the resource's email matches an account.
  belongs_to :user, optional: true
  before_save :link_user, if: -> { user_id.nil? && will_save_change_to_email? }

  def link_user
    return unless category == 'OVERHEAD' && email.present?
    self.user = User.find_by('LOWER(email) = ?', email.strip.downcase)
  end

  # Still on the incident: not released, and either the last work day
  # hasn't passed or (with no dates) it was checked in recently. The
  # recency guard keeps a never-demobed old row from showing someone as
  # on assignment forever.
  def current_assignment?
    return false if spacer? || release_date.present?
    lwd = last_work_day
    lwd.is_a?(Date) ? lwd >= Date.current : created_at >= 30.days.ago
  end

  # "LAST, FIRST MIDDLE" (how IROC / check-in forms arrive) → "FIRST
  # MIDDLE LAST" for display as a Leader name. Idempotent: strings
  # without a comma pass through unchanged, so re-formatting an already-
  # swapped value doesn't double-flip. Trims runs of whitespace.
  def self.format_leader_name(raw)
    s = raw.to_s.strip
    return s if s.empty?
    return s unless s.include?(',')
    last, rest = s.split(',', 2)
    [rest.to_s.strip, last.to_s.strip].reject(&:empty?).join(' ').squeeze(' ')
  end
  has_one :org_unit_assignment, dependent: :destroy
  has_one :org_unit, through: :org_unit_assignment
  has_many :rosters, dependent: :destroy
  # Inverse of Roster#promoted_resource — rosters on OTHER resources that
  # point here because this record was promoted off their roster. We
  # don't own those rows (the parent resource does), so just nullify the
  # pointer on destroy.
  has_many :promoted_from_rosters,
           class_name: 'Roster',
           foreign_key: :promoted_resource_id,
           dependent:   :nullify,
           inverse_of:  :promoted_resource

  # Belt-and-suspenders: the dependent: :nullify above should handle it,
  # but incident teardown has been observed to still hit the
  # fk_rails_0f4a109932 FK violation on rosters.promoted_resource_id —
  # likely because the destroy order between the owning resource and
  # the referenced (promoted) resource races. This explicit callback
  # fires an unconditional UPDATE before DELETE so the FK is clear
  # regardless of order.
  before_destroy :nullify_roster_promotion_refs

  def nullify_roster_promotion_refs
    Roster.where(promoted_resource_id: id).update_all(promoted_resource_id: nil)
  end
  has_many :resource_events, -> { order(:created_at) }, dependent: :destroy
  # demob_notifications.resource_id carries a DB-level FK. Incident owns
  # these too, but Rails cascades dependents in declaration order and
  # resources is declared first, so without this line each resource gets
  # DELETEd while its notifications still reference it → incident.destroy
  # fails with ForeignKeyViolation. Owning them here cleans them up as
  # part of the resource's own destroy cascade.
  has_many :demob_notifications, dependent: :destroy
  # Requests keep their copied identity fields if the resource goes away.
  has_many :air_travel_requests, dependent: :nullify
  # Same shape as demob_notifications: PlanAssignmentSnapshot has a
  # DB-level FK to resources, Plan owns the collection, but Resource
  # didn't — so deleting a resource (even a blank spacer) would fail
  # with a FK violation. Owning them here cleans snapshots up inside
  # the resource's own destroy cascade. Snapshots are frozen records
  # of what was on a published plan; destroying them when the resource
  # itself is gone is consistent with the Roster/Demob pattern.
  has_many :plan_assignment_snapshots, dependent: :destroy

  scope :unassigned, lambda {
    left_outer_joins(:org_unit_assignment)
      .where(org_unit_assignments: { id: nil })
  }
  scope :overhead, -> { where(category: 'OVERHEAD') }
  scope :equipment, -> { where(category: 'EQUIPMENT') }
  scope :crew, -> { where(category: 'CREW') }
  scope :aircraft, -> { where(category: 'AIRCRAFT') }
  # "active" = not released, not on R&R (matches historical `assigned`
  # semantics). "assigned" narrows that to real resources — spacers exist
  # only as visual gaps on the ICS 204 board and must be filtered out of
  # every user-facing resource list (ICS 211, demob, plan roster, etc.);
  # the board itself uses `.active` so spacers still render on columns.
  # Shift-timeline: "on R&R" and "active" are derived from :rnr events
  # whose planned window covers today. r_and_r boolean is dual-written
  # from these via sync_rnr_timeline_from_boolean so legacy readers and
  # form submissions still work during the transition. The boolean will
  # be dropped once all callers are migrated.
  scope :on_rnr, -> {
    where(spacer: false).where(id: ResourceEvent.rnr_in_effect
      .select(:resource_id).distinct)
  }
  scope :active, -> {
    where(release_date: nil).where.not(id: ResourceEvent.rnr_in_effect
      .select(:resource_id))
  }
  scope :assigned, -> { active.where(spacer: false) }
   with_options unless: :spacer? do
     validates :name, presence: true
     validates :position, presence: true
     validates :agency, presence: true
     validates :order_number, presence: true
     validates :number_personnel, presence: true
     validates :assignment_length, presence: true
     validates :category, presence: true
   end
   # Prevents manual creation of a Resource whose full_order_number would
   # collide with one already on the incident — otherwise we couldn't rely on
   # the Req# ↔ full_order_number tie to compute check-in status.
   validates :order_number,
             uniqueness: {
               scope:   [:incident_id, :category],
               message: "is already used for a resource of this category on this incident"
             },
             if: -> { incident_id.present? && category.present? && order_number.present? }

  after_create :create_demob, unless: :spacer?

  # Position-code buckets for the auto-router. Each list maps a set of
  # NWCG position codes → the org unit a newly-created Resource should
  # land on (instead of sitting in Unassigned). Codes are matched case-
  # insensitively against Resource#position. Fires for both hand-created
  # resources and iSuite-imported ones via the after_create below.
  #
  # Precedence: COMMAND / PLANS / LOGISTICS / FINANCE / OPERATIONS win
  # over NON_209 when a code appears in both — section lists are more
  # specific placements, NON_209 is the catch-all for off-209 support.
  COMMAND_POSITIONS = %w[
    ICT1 ICT2 ICT3 ICT4 ICT5 ICA2 ICA3 ACDR PIOF PIO1 PIO2 PIO3 PIA2
    SOF1 SOF2 SOF3 SOA2 SOFR SOFO LOFR
  ].to_set.freeze

  OPERATIONS_POSITIONS = %w[
    OSC1 OSC2 OSC3 OPS3 OSA2 OPBD DIVA DIVS DLEO DSAR ATFL TFLD STCR
    STEN STEQ STLM
  ].to_set.freeze

  PLANS_POSITIONS = %w[
    PSCC PSC1 PSC2 PSC3 PSA2 ACPC RESL SITL SIAL DMOB DOCL SCKN DPRO
    FOBS FBAN FEMO GISS HRSP IRIN IARR LTAN SOPL TNSP WOBS FLIR IMET
    GEOG GEOL GEOP OCEA SCEN SCPH
  ].to_set.freeze

  LOGISTICS_POSITIONS = %w[
    LSCC LSC1 LSC2 LSC3 COML COMC COMT FACL GSUL SPUL FDUL MEDL BCMG
    STAM ORDM FCMG WHLR WHHR CASC CAST CDSP EQPM EQPI DRIV DRVA DRVB
    LOAD MOTL MOTS KMGR CAMP
  ].to_set.freeze

  FINANCE_POSITIONS = %w[
    FSCC FSC1 FSC2 FSC3 COST COSP TIME PROC COMP CLMS INJR PTRC EQTR
    FTSC CATS CONS COPA COTR PPTS
  ].to_set.freeze

  NON_209_POSITIONS = %w[
    AADM ACDP AREP ARPL AUTO BLGT BSU1 BSU2 BSU3 BUSH BUYL BUYM BUYT BWFS
    CLSU COM1 COM2 COM3 COMA COTR DUTY ELEC EOCO FLAT FLIA FLOP FORK GENR
    GOLF GWT1 GWT2 GWT3 GWT4 GWTA HND1 HND2 HNDA HVAC IADP IBU1 IBU2 LAU1
    LAU2 LITK LITR MBLP MCCO MCIF MEDV MESU MESV MFSU MKUS MOTL MOTS MSFU
    OFFT PIRD PLJK POT1 POT2 POT3 POT4 POTA PPTS PROB PRSS PUP1 PUP2 PUP3
    PWSP RAPT REF1 REF2 REF3 REFA REPP SATP SATR SATS SCDB SIRF SLGT SLP1
    SLP2 SLP3 SLPA SLRR SMEC SMKM SMRB STFR STK1 STK2 STKA STMH STML STMT
    TNT1 TNT2 TNT3 TNT4 TNTA TOWT TPPU TRQA TTCH TUBG UTT1 UTT2 VANB VANP
    VSRS VTEC VUTV WEBS WEED WHHR WHLR WWCB
  ].to_set.freeze

  # Five General Staff buckets used by the glide-path section filter.
  ICS_SECTIONS = %w[Command Operations Plans Logistics Finance].freeze

  # Routing table — ORDER MATTERS. First matching entry wins, so sections
  # (command/plans/logistics/finance/operations) take precedence over the
  # Non-209 catch-all.
  AUTO_ROUTE_TABLE = [
    { codes: COMMAND_POSITIONS,    kind:         :command    },
    { codes: PLANS_POSITIONS,      section_name: 'Plans'     },
    { codes: LOGISTICS_POSITIONS,  section_name: 'Logistics' },
    { codes: FINANCE_POSITIONS,    section_name: 'Finance'   },
    { codes: OPERATIONS_POSITIONS, section_name: 'Operations' },
    { codes: NON_209_POSITIONS,    kind:         :non_209    }
  ].freeze

  after_create :auto_route_by_position, unless: :spacer?

  # Demobed resources shouldn't linger as OrgUnitAssignments on the board.
  # The board hides them via `.active`, but leaving the row lets them leak
  # into any downstream lookup that doesn't filter — e.g. a 204 built later
  # against the same org_unit. Only fires when release_date was actually
  # set on this save (nil → date), so clearing release_date to bring
  # someone back doesn't do anything weird.
  after_save :sync_current_work_entry
  after_save :remove_from_board_on_demob, if: :saved_change_to_release_date?
  after_save :close_current_work_on_demob,  if: :saved_change_to_release_date?
  after_save :sync_rnr_timeline_from_boolean, if: :saved_change_to_r_and_r?
  after_update :cascade_agency_to_rosters, if: :saved_change_to_agency?

  # The tally counts roster rows by their OWN agency (personnel_by_agency),
  # while the 211 shows the parent's. Equipment is often dispatched as
  # USFS and corrected to PVT at check-in — without this, the operators
  # stay counted under USFS. Only rows still on the old agency (or blank)
  # follow; rows deliberately set to something else (MULTI modules,
  # agency staff on a contract aircraft) are left alone.
  def cascade_agency_to_rosters
    old_agency, new_agency = saved_change_to_agency
    rosters.unscope(:order)
           .where(agency: [old_agency, nil, ''].uniq)
           .update_all(agency: new_agency, updated_at: Time.current)
  end

  def remove_from_board_on_demob
    return if release_date.nil?
    org_unit_assignment&.destroy
  end

  # When a resource is demobbed (release_date set), close out the
  # currently-active :work entry so the shift timeline agrees with the
  # resource row. If release_date is cleared (resource brought back),
  # reopen the most recently-closed entry whose actual_lwd matches the
  # previous release_date.
  def close_current_work_on_demob
    before, after = saved_change_to_release_date
    if after.present?
      resource_events.where(kind: ResourceEvent.kinds[:work])
                     .where.not(actual_fwd: nil)
                     .where(actual_lwd: nil)
                     .update_all(actual_lwd: after, updated_at: Time.current)
    elsif before.present?
      resource_events.where(kind: ResourceEvent.kinds[:work], actual_lwd: before)
                     .order(updated_at: :desc).limit(1)
                     .update_all(actual_lwd: nil, updated_at: Time.current)
    end
  end

  # Keep the current :work entry (if any) in sync with the Resource
  # row, and create the FIRST :work entry for a resource that doesn't
  # have one yet. Without this, a freshly-filled resource lives only
  # on the Resource row until a swap happens — swap_now then has no
  # entry to close out and the first operator never appears in the
  # activity feed (reported bug on E-175).
  def sync_current_work_entry
    return if spacer?
    return unless fwd.present?
    effective_leader = leader.presence || name
    return if effective_leader.blank?

    planned_end = (fwd + assignment_length.to_i - 1.day) if assignment_length.to_i.positive?

    current = resource_events.where(kind: ResourceEvent.kinds[:work])
                             .where.not(actual_fwd: nil)
                             .where(actual_lwd: nil)
                             .first

    if current
      # Mirror leader / phone / planned-end onto the entry so the feed
      # stays consistent with inline edits to the Resource row. fwd
      # stays as the operator's actual start date — resource.fwd is the
      # equipment's original check-in and shouldn't drag the operator's
      # start back.
      attrs = {}
      attrs[:leader] = effective_leader if current.leader != effective_leader
      attrs[:phone]  = phone             if current.phone  != phone
      attrs[:lwd]    = planned_end       if planned_end && current.lwd != planned_end
      current.update_columns(attrs.merge(updated_at: Time.current)) if attrs.any?
    elsif release_date.blank? &&
          !resource_events.where(kind: ResourceEvent.kinds[:work]).exists?
      # First :work entry for this resource. Only when there are NO
      # :work entries at all — if the chain closed out and the resource
      # is between operators we don't want to invent one.
      resource_events.create!(
        kind:       :work,
        leader:     effective_leader,
        phone:      phone,
        fwd:        fwd,
        lwd:        planned_end,
        actual_fwd: fwd,
        actual_lwd: nil
      )
    end
  end

  # Dual-write: the legacy R&R checkbox (on _non_209 / _ics_211) still
  # saves the r_and_r boolean. Mirror the flip to the :rnr timeline so
  # the new scopes (active / on_rnr) and anything else reading from the
  # events stays in sync. Dropping r_and_r in #96 drops this callback.
  def sync_rnr_timeline_from_boolean
    today = Date.current
    if r_and_r
      has_active = resource_events.rnr_in_effect(today).exists?
      resource_events.create!(
        kind: :rnr, fwd: today, lwd: today + 1.day, actual_fwd: today
      ) unless has_active
    else
      resource_events.rnr_in_effect(today)
                     .update_all(actual_lwd: today, updated_at: Time.current)
    end
  end

  # Drop a newly-created resource onto the appropriate section org unit
  # based on its position code. AUTO_ROUTE_TABLE is checked in order;
  # the first matching bucket wins (Plans/Logistics/Finance before
  # Non-209). Idempotent: skips if an OrgUnitAssignment already exists
  # (e.g. an iSuite re-import), skips when the target org unit is
  # missing on the incident, and rescues so a routing failure never
  # blocks resource creation.
  def auto_route_by_position
    return if position.blank?
    return if org_unit_assignment.present?

    code = position.to_s.strip.upcase
    bucket = AUTO_ROUTE_TABLE.find { |b| b[:codes].include?(code) }
    return unless bucket

    target = target_org_unit_for(bucket)
    return unless target

    OrgUnitAssignment.create!(resource: self, org_unit: target)
  rescue => e
    Rails.logger.warn "Resource##{id} auto_route_by_position failed: #{e.class}: #{e.message}"
    nil
  end

  # Which General Staff section this resource belongs to for the glide-
  # path section filter. Prefers the resource's actual org_unit root
  # (section or command). Falls back to the position-code routing table
  # when the resource isn't on the board yet or sits under a non-209
  # bucket. Returns nil only when neither path yields a classification.
  def ics_section
    if org_unit.present?
      root = org_unit
      root = root.parent while root.parent.present?
      return 'Command' if root.kind_command?
      return root.name if root.kind_section? && ICS_SECTIONS.include?(root.name)
    end
    return nil if position.blank?
    bucket = AUTO_ROUTE_TABLE.find { |b| b[:codes].include?(position.to_s.strip.upcase) }
    return nil unless bucket
    return 'Command' if bucket[:kind] == :command
    bucket[:section_name]
  end

  def target_org_unit_for(bucket)
    if bucket[:kind]
      incident.org_units.where(kind: OrgUnit.kinds[bucket[:kind]]).first
    elsif bucket[:section_name]
      incident.section(bucket[:section_name])
    end
  end

  # Guard against ActiveRecord's stricter date coercion turning
  # "8/20/26" (from the datepicker or a form typo) into year 0026.
  # Any parsed date whose year is below 100 gets bumped by 2000 so it
  # lands in the intended 21st century range.
  %i[fwd checkin_date mobilization_date].each do |attr|
    define_method("#{attr}=") do |value|
      super(value)
      current = self[attr]
      if current.is_a?(Date) && current.year < 100
        self[attr] = Date.new(current.year + 2000, current.month, current.day)
      end
    end
  end


  def cat
    case self.category
    when 'OVERHEAD'
      'O-'
    when 'CREW'
      'C-'
    when 'EQUIPMENT'
      'E-'
    when 'AIRCRAFT'
      'A-'
    end
  end

  # Projected end-of-assignment date.
  #
  # Shift-timeline model: each :work entry carries its own planned
  # start (fwd) and planned end (lwd). last_work_day = max end across
  # all :work entries — captures both the current operator's planned
  # end and any future (unpromoted) scheduled operators. Taking the
  # MAX across the whole timeline means a shorter future entry can't
  # shrink the committed end date.
  #
  # A finished entry counts by the day it actually ended. Its planned
  # lwd is never updated after it closes, so an old plan (e.g. the
  # original 14 days) would otherwise outrank a shortened current shift
  # (reported bug on E-522).
  #
  # Fallback for resources that haven't been through the shift
  # backfill (shouldn't happen in production after the one-time
  # backfill, but keeps the method honest for freshly-created rows):
  # fwd + assignment_length - 1 day.
  #
  # Preserves the historical " " return value when nothing is on the
  # timeline AND fwd/assignment_length are both missing, so legacy
  # callers that pattern-match on `is_a?(String)` keep working.
  def last_work_day
    work_lwds = work_entries.map { |e| e.actual_lwd || e.lwd }.compact
    return work_lwds.max if work_lwds.any?
    return fwd + assignment_length - 1.days if fwd && assignment_length
    " "
  end

  # Max LWD across future (unpromoted) :work entries. "Unpromoted" =
  # actual_fwd IS NULL — the entry hasn't been made current by a
  # SWAP NOW yet. Nil when none exist. Kept for callers that still
  # reference the pre-refactor name.
  def latest_scheduled_swap_lwd
    work_entries.select { |e| e.actual_fwd.nil? }.map(&:lwd).compact.max
  end

  # Dates a crew swap actually happened: each promoted :work entry whose
  # leader differs from the entry before it. The first entry is the
  # original operator, and a same-leader entry is a return from R&R, so
  # neither counts.
  def completed_swap_dates
    work_entries.select(&:actual_fwd).sort_by(&:actual_fwd).each_cons(2)
                .reject { |prev, entry| prev.leader == entry.leader }
                .map { |_prev, entry| entry.actual_fwd }
  end

  # R&R days already taken: anything before today, plus every day of an
  # R&R that was ended by dragging the card off the R&R board.
  def completed_rnr_dates
    rnr_entries.flat_map { |e| e.rnr_dates.select { |day| e.actual_lwd || day < Date.current } }.uniq
  end

  # R&R days still to come, including today for an R&R under way.
  def scheduled_rnr_dates
    rnr_entries.reject(&:actual_lwd).flat_map(&:rnr_dates).select { |day| day >= Date.current }.uniq
  end

  # :work entries for this resource. Uses the in-memory association
  # when it's been eager-loaded (common on the board + 211 pages) to
  # avoid a per-row SQL query.
  def work_entries
    if resource_events.loaded?
      resource_events.select { |e| e.kind.to_s == 'work' }
    else
      resource_events.where(kind: ResourceEvent.kinds[:work])
    end
  end

  # :rnr entries for this resource, using the loaded collection when
  # there is one.
  def rnr_entries
    if resource_events.loaded?
      resource_events.select { |e| e.kind.to_s == 'rnr' }
    else
      resource_events.where(kind: ResourceEvent.kinds[:rnr])
    end
  end

  # The currently-active :work entry (actual_fwd set, actual_lwd nil).
  # Nil when there's no current operator. Prefers the loaded collection.
  def current_work_entry
    work_entries.detect { |e| e.actual_fwd.present? && e.actual_lwd.nil? }
  end

  def formatted_fwd
    if self.fwd
     return self.fwd.strftime("%m/%d")
   end
  end
  def formatted_release_date
    if self.release_date
     return self.release_date.strftime("%m/%d")
   end
  end

  def full_order_number
   return "#{self.cat}#{self.order_number}"
  end

  def released?
    return true if self.release_date
  end

  # Breaks the resource's personnel count down by agency. When a roster
  # exists (imported subordinates), each CHECKED-IN roster row is one
  # person in its own agency; "Filled" rosters are listed but excluded
  # from the live count so a 20-person crew that only sent 15 can show
  # all 20 names without inflating the tally. When no roster exists at
  # all, the whole crew rolls up under the parent resource's agency
  # using number_personnel.
  #
  # If `rosters` was eager-loaded by the caller (common on the T-card
  # board + ICS 211), we filter in Ruby to avoid firing a fresh query
  # per resource. Falls back to SQL when the association wasn't
  # preloaded.
  def personnel_by_agency
    if rosters.loaded?
      live = rosters.select { |r| r.released_at.nil? && r.promoted_resource_id.nil? && r.status.to_s == 'C' }
      return { agency => number_personnel.to_i } if live.empty? && rosters.empty?
      live.group_by { |r| r.agency.presence || agency }.transform_values(&:count)
    elsif rosters.exists?
      rosters.active.unpromoted.checked_in
             .group_by { |r| r.agency.presence || agency }
             .transform_values(&:count)
    else
      { agency => number_personnel.to_i }
    end
  end

  # Sum of personnel_by_agency values — the number actually present on
  # the incident right now. Prefer this over `number_personnel` anywhere
  # you're showing a live count so promotions/subordinate demobs are
  # reflected correctly.
  def effective_personnel
    personnel_by_agency.values.sum
  end

  # True iff a scheduled :rnr entry's planned window covers today and
  # it hasn't been closed out. Uses in-memory :rnr entries when the
  # association is preloaded (board / ICS 211 both eager-load) to
  # avoid a per-row SQL query.
  def rnr?
    rnr_entries.any?(&:rnr_in_effect?)
  end

  # Card dragged to the R&R board ahead of its scheduled start, usually
  # while building the next shift's IAP. Keeps the planned dates. Returns
  # nil when there's no upcoming R&R, since the end date is what brings
  # the card back.
  def start_rnr_early!
    upcoming = rnr_entries.select { |e| e.actual_fwd.nil? && e.actual_lwd.nil? && e.lwd && e.lwd >= Date.current }
                          .min_by(&:fwd)
    upcoming&.update!(actual_fwd: Date.current)
    upcoming
  end

  # Card dragged off the R&R board. An early start is undone so the
  # scheduled R&R still happens; one already under way ends today.
  def end_rnr!
    rnr_entries.select(&:rnr_in_effect?).each do |entry|
      if entry.fwd > Date.current
        entry.update!(actual_fwd: nil)
      else
        entry.update!(actual_lwd: Date.current)
      end
    end
  end

  def create_demob
    Demob.create!(resource_id: self.id)
  end

  def demob
    Demob.where(resource_id: self.id).first
  end


end
