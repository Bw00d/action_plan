class Plan < ApplicationRecord
  belongs_to :user, optional: true
  # If you need to access the user, delegate through incident
  delegate :owner, to: :incident, prefix: true, allow_nil: true
  # This gives you plan.incident_owner
  belongs_to :incident
  has_many :assignments, dependent: :destroy
  has_many :objectives, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_one :commo_plan, dependent: :destroy
  has_one :safety_message, dependent: :destroy
  has_many :teams, dependent: :destroy
  has_one :cover, dependent: :destroy
  has_many :attachments, dependent: :destroy
  has_many :assignment_snapshots, class_name: 'PlanAssignmentSnapshot', dependent: :destroy
  validates :date, presence: true
  validates_uniqueness_of :date, :scope => :incident_id

  def published?
    published_at.present?
  end

  def draft?
    !published?
  end
  after_create :duplicate_plan
  after_create :add_attachments
  

  def duplicate_plan
    if self.incident.plans.count >= 2
      self.duplicate_objectives
      self.duplicate_202_fields
      self.duplicate_teams
      self.duplicate_assignments
      self.duplicate_commo_plan
      self.duplicate_safety_message
      self.duplicate_cover
    end
  end

  # 202 free-text carries over — Objective records + SafetyMessage are
  # handled by their own duplicate_* methods. update_columns writes
  # directly to bypass callbacks (we're already inside after_create).
  #
  # Covers:
  #   §3  objectives_text              (Objectives free text)
  #   §4  weather                      (Operational Period Command Emphasis)
  #       general_safety               (General Situational Awareness)
  #   §5  site_safety_plan_required    (Yes/No)
  #       site_safety_plan_location    (Approved SSP location)
  def duplicate_202_fields
    prev = self.incident.plans.last(2).first
    return unless prev
    self.update_columns(
      objectives_text:            prev.objectives_text,
      weather:                    prev.weather,
      general_safety:             prev.general_safety,
      site_safety_plan_required:  prev.site_safety_plan_required,
      site_safety_plan_location:  prev.site_safety_plan_location
    )
  end

  # Cover + all its blocks + the main_image attachment on each block. Block
  # layout fields (x, y, width, height, font_*) travel via .dup; images are
  # blob-shared via .attach(old_blob).
  #
  # Each block is wrapped in its own begin/rescue so a bad blob (or any
  # per-block failure) doesn't abort the whole plan creation. Verbose
  # logging is on so `heroku logs | grep duplicate_cover` shows exactly
  # what happened for the last plan create.
  def duplicate_cover
    prev = self.incident.plans.last(2).first
    if prev.nil?
      Rails.logger.info "duplicate_cover: plan #{self.id} — no previous plan, skipping"
      return
    end
    if prev.cover.nil?
      Rails.logger.info "duplicate_cover: plan #{self.id} — previous plan #{prev.id} has no cover, skipping"
      return
    end

    new_cover = Cover.create!(plan_id: self.id)
    block_count = prev.cover.blocks.count
    Rails.logger.info "duplicate_cover: plan #{self.id} — cover #{new_cover.id} created, copying #{block_count} block(s) from cover #{prev.cover.id}"

    prev.cover.blocks.each do |old_block|
      begin
        new_block = old_block.dup
        new_block.cover_id = new_cover.id
        new_block.save!

        if old_block.main_image.attached?
          new_block.main_image.attach(old_block.main_image.blob)
          Rails.logger.info "duplicate_cover: plan #{self.id} — copied block #{old_block.id} -> #{new_block.id} WITH image"
        else
          Rails.logger.info "duplicate_cover: plan #{self.id} — copied block #{old_block.id} -> #{new_block.id} (no image)"
        end
      rescue => e
        Rails.logger.warn "duplicate_cover: plan #{self.id} — block #{old_block.id} copy failed: #{e.class}: #{e.message}"
      end
    end
  end

  def duplicate_objectives
      self.incident.plans.last(2).first.objectives.each do |o|
        Objective.create(plan_id: self.id, description: o.description, order: o.order)
      end
  end

  def duplicate_teams
    if self.incident.plans.last(2).first.teams
      self.incident.plans.last(2).first.teams.each do |t|
        team = t.dup
        team.update_attributes(plan_id: self.id)
      end
    end
  end

  def duplicate_assignments
    if self.incident.plans.last(2).first.assignments
      self.incident.plans.last(2).first.assignments.each do |a|
        assignment = a.dup
        assignment.update_attributes(plan_id: self.id)
      end
    end
  end

  # Clone the previous plan's ICS 205. Catch: CommoPlan's after_create
  # callback `seed_first_page` auto-creates 16 blank channels the moment
  # the new row is saved — so without clearing those, we end up with the
  # 16 blanks PLUS the copied channels on top (32 total → an extra blank
  # page). Destroy the seeded blanks before copying.
  def duplicate_commo_plan
    prev = self.incident.plans.last(2).first
    return unless prev&.commo_plan

    new_cp = prev.commo_plan.dup
    new_cp.plan_id = self.id
    new_cp.save!                   # triggers seed_first_page → 16 blanks
    new_cp.commo_items.destroy_all # wipe them before importing the real set

    prev.commo_plan.commo_items.order(:id).each do |item|
      copied = item.dup
      copied.commo_plan_id = new_cp.id
      copied.save!
    end
  end

  def duplicate_safety_message
    if self.incident.plans.last(2).first.safety_message
       SafetyMessage.create( plan_id: self.id, hazards: self.incident.plans.last(2).first.safety_message.hazards)
    end
  end

  # ICS 202 section 6: 18-slot grid (3 columns × 6 rows). First 11
  # slots seeded with standard ICS form names; the remaining 7 start
  # blank so the user can label them however they like. All 18 are
  # editable — the pre-seeded names are just defaults.
  ICS_202_ATTACHMENTS = [
    "ICS 202", "ICS 203", "ICS 204", "ICS 205", "ICS 205A", "ICS 206",
    "ICS 207", "ICS 208", "ICS 220", "Map/Chart", "Forecasts"
  ].freeze
  ICS_202_ATTACHMENT_SLOTS = 18

  # Section 6 attachments. If a previous plan exists on the incident,
  # carry over its 18 slots verbatim (description + attached state) so
  # custom labels and ticked boxes persist to the next operational
  # period. Falls back to the seeded defaults for the very first plan.
  def add_attachments
    prev = self.incident.plans.where.not(id: self.id).order(:id).last
    if prev && prev.attachments.any?
      prev.attachments.order(:id).each do |a|
        Attachment.create!(
          plan_id:     self.id,
          description: a.description,
          attached:    a.attached
        )
      end
    else
      blanks = Array.new(ICS_202_ATTACHMENT_SLOTS - ICS_202_ATTACHMENTS.length, "")
      (ICS_202_ATTACHMENTS + blanks).each do |a|
        Attachment.create!(description: a, plan_id: self.id)
      end
    end
  end

  def command_staff
    Team.where(plan_id: self.id, staff: "Command").order(:list_position, :created_at)
  end

  def agency_reps
    Team.where(plan_id: self.id, staff: "Agency").order(:list_position, :created_at)
  end

  def plans
    Team.where(plan_id: self.id, staff: "Plans").order(:list_position, :created_at)
  end

  def finance
    Team.where(plan_id: self.id, staff: "Finance").order(:list_position, :created_at)
  end

  def operations
    Team.where(plan_id: self.id, staff: "Operations").order(:list_position, :created_at)
  end

  def logistics
    Team.where(plan_id: self.id, staff: "Logistics").order(:list_position, :created_at)
  end

  # ── 202 header: Date/Time From/To setters ────────────────────
  # Accept "MM/DD/YYYY HHMM" (military time, no colon) — matches the
  # 204 pattern — plus anything Time.zone.parse can handle. Blank or
  # unparseable input clears the field rather than raising, so a user
  # typing over the input doesn't lose their save.
  def ops_period_from=(value)
    super(parse_ops_datetime(value))
  end

  def ops_period_to=(value)
    super(parse_ops_datetime(value))
  end

  # 203 footer "Date/Time:" prepared-at. Same parser as the ops-period
  # fields so users can type MM/DD/YYYY HH:MM (or HHMM) on the 203 and
  # have it stored as a proper datetime.
  def prepared_at=(value)
    super(parse_ops_datetime(value))
  end

  # ICS 202 "shift" selector. The dropdown offers DAY / NIGHT / blank;
  # the blank option carries the sentinel "BLANK" (best_in_place 3.x
  # has trouble re-rendering a select display when the submitted value
  # is an empty string). Normalize the sentinel + any plain blank back
  # to nil so the DB stores NULL for an unset shift.
  def shift=(value)
    normalized = value.to_s.strip
    normalized = nil if normalized.blank? || normalized.casecmp('blank').zero?
    super(normalized)
  end

  private

  def parse_ops_datetime(value)
    return value unless value.is_a?(String)
    return nil if value.blank?

    s = value.strip
    if s =~ %r{\A(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{2}):?(\d{2})\z}
      Time.zone.local(Regexp.last_match(3).to_i, Regexp.last_match(1).to_i,
                      Regexp.last_match(2).to_i, Regexp.last_match(4).to_i,
                      Regexp.last_match(5).to_i)
    else
      Time.zone.parse(s)
    end
  rescue ArgumentError
    nil
  end
end
