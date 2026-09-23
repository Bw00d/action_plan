class Demob < ApplicationRecord
  belongs_to :resource
  # Present when this demob sheet is for a single subordinate roster
  # entry rather than the parent resource itself. Both cases live in the
  # same table; resource_id points at the parent either way.
  belongs_to :roster, optional: true
  has_one :demob_notification, dependent: :destroy
  after_create :set_units
  has_many :units, dependent: :destroy
  after_update :release_resource
  after_update :create_demob_notification


  def formatted_release_date
     self.actual_release_date.strftime("%m/%d") if self.actual_release_date?
  end

  private
  # Bi-directional demob sync.
  # - When actual_release_date is set, mark the roster released (for a
  #   subordinate demob) or the resource released (for a normal demob).
  # - When the date is cleared (nil), UN-demob — clear the roster's
  #   released_at or the resource's release_date so the record shows up
  #   again on the T-cards board / ICS-211 / tally. Also drop the
  #   DemobNotification so this record isn't sitting in the notifications
  #   tab as "released".
  # The parent's personnel count follows via Resource#personnel_by_agency.
  def release_resource
    return unless saved_change_to_actual_release_date?

    if actual_release_date.present?
      if roster
        roster.release!(at: actual_release_date)
      else
        resource.update(release_date: actual_release_date)
      end
    else
      if roster
        roster.update(released_at: nil) if roster.released_at.present?
      else
        resource.update(release_date: nil) if resource.release_date.present?
      end
      demob_notification&.destroy
    end
  end

  # Snapshots this Demob into a DemobNotification the first time an actual
  # release date is filled in. Idempotent — DemobNotification.from_demob
  # short-circuits if one already exists.
  def create_demob_notification
    return unless saved_change_to_actual_release_date? && actual_release_date.present?
    DemobNotification.from_demob(self)
  end

  def set_units
    count = 1
    units = ["Supply Unit", "Communications Unit", "Facilities Unit", "Ground Support Unit", "Security manager",
             "", "Time Unit", "", "", "", "", "", "Documentation Unit", "Demob Unit"]
    units.each do |u|
      Unit.create(demob_id: self.id, manager: u, order: count)
      count += 1
    end
  end
end
