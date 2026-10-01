class Resource < ApplicationRecord
  belongs_to :incident
  has_one :demob
  has_one :org_unit_assignment, dependent: :destroy
  has_one :org_unit, through: :org_unit_assignment
  has_many :rosters, dependent: :destroy
  # demob_notifications.resource_id carries a DB-level FK. Incident owns
  # these too, but Rails cascades dependents in declaration order and
  # resources is declared first, so without this line each resource gets
  # DELETEd while its notifications still reference it → incident.destroy
  # fails with ForeignKeyViolation. Owning them here cleans them up as
  # part of the resource's own destroy cascade.
  has_many :demob_notifications, dependent: :destroy

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
  scope :active,   -> { where(release_date: nil, r_and_r: false) }
  scope :assigned, -> { active.where(spacer: false) }
  scope :on_rnr,   -> { where(r_and_r: true, spacer: false) }
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
  after_save :remove_from_board_on_demob, if: :saved_change_to_release_date?

  def remove_from_board_on_demob
    return if release_date.nil?
    org_unit_assignment&.destroy
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
  %i[fwd checkin_date].each do |attr|
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

  def last_work_day
    if self.fwd && self.assignment_length
      return self.fwd + self.assignment_length-1.days 
    else
      return " "
    end
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
  # exists (imported subordinates), each active roster row is one person
  # in its own agency; when no roster exists, the whole crew rolls up
  # under the parent resource's agency using number_personnel.
  def personnel_by_agency
    if rosters.exists?
      rosters.active.unpromoted
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

  def rnr?
    return true if self.r_and_r
  end

  def create_demob
    Demob.create!(resource_id: self.id)
  end

  def demob
    Demob.where(resource_id: self.id).first
  end


end
