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
  # layout fields (x, y, width, height, font_*) travel via .dup. Images are
  # downloaded and re-uploaded as fresh blobs (not blob-shared via
  # .attach(existing_blob)) so each plan owns its own storage — that way
  # deleting or replacing an image on one plan can't affect another. Attach
  # runs BEFORE save so the attachment auto-persists with the record; the
  # rescue keeps a per-block image failure from aborting the whole plan.
  def duplicate_cover
    prev = self.incident.plans.last(2).first
    return unless prev && prev.cover

    new_cover = Cover.create!(plan_id: self.id)
    prev.cover.blocks.each do |old_block|
      begin
        new_block = old_block.dup
        new_block.cover_id = new_cover.id

        if old_block.main_image.attached?
          old_blob = old_block.main_image.blob
          new_block.main_image.attach(
            io:           StringIO.new(old_blob.download),
            filename:     old_blob.filename.to_s,
            content_type: old_blob.content_type
          )
        end

        new_block.save!
      rescue => e
        Rails.logger.warn "duplicate_cover: block #{old_block.id} copy failed for plan #{self.id}: #{e.class}: #{e.message}"
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

  def add_attachments
    attachments = ["ORGANIZATION LIST", "ASSIGNMENT LIST", "COMMUNITCATIONS PLAN", "MEDICAL PLAN", "FINANCE MESSAGE","INCIDENT MAP",
                    "TRAFFIC PLAN", "_______________", "_______________", "_______________", "_______________", "_______________"]
    attachments.each do |a|
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
