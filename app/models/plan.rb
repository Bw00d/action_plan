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

  # 202 free-text carries over — Objectives + SafetyMessage are handled by
  # their own duplicate_* methods. update_columns writes directly to bypass
  # callbacks (we're already inside after_create).
  def duplicate_202_fields
    prev = self.incident.plans.last(2).first
    return unless prev
    self.update_columns(
      weather:        prev.weather,
      general_safety: prev.general_safety
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

  def duplicate_commo_plan
    if self.incident.plans.last(2).first.commo_plan
      commo_plan = self.incident.plans.last(2).first.commo_plan.dup
      commo_plan.update_attributes(plan_id: self.id)
      self.incident.plans.last(2).first.commo_plan.commo_items.each do |item|
        new_item = item.dup
        new_item.update_attributes(commo_plan_id: commo_plan.id)
      end
    end
  end

  def duplicate_safety_message
    if self.incident.plans.last(2).first.safety_message
       SafetyMessage.create( plan_id: self.id, hazards: self.incident.plans.last(2).first.safety_message.hazards)
    end
  end

  # ICS 202 section 6 layout: 11 predefined form checkboxes on the left,
  # 4 user-editable "Other Attachments" slots on the right. Descriptions
  # for the left column are locked to the standard ICS form names; the
  # right column starts blank so the user can name them anything.
  ICS_202_ATTACHMENTS = [
    "ICS 202", "ICS 203", "ICS 204", "ICS 205", "ICS 205A", "ICS 206",
    "ICS 207", "ICS 208", "ICS 220", "Map/Chart", "Weather Forecast/Tides/Currents"
  ].freeze

  def add_attachments
    (ICS_202_ATTACHMENTS + ["", "", "", ""]).each do |a|
      Attachment.create!(description: a, plan_id: self.id)
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

end
