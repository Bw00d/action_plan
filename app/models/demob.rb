class Demob < ApplicationRecord
  belongs_to :resource
  has_one :demob_notification, dependent: :destroy
  after_create :set_units
  has_many :units, dependent: :destroy
  after_update :release_resource
  after_update :create_demob_notification


  def formatted_release_date
     self.actual_release_date.strftime("%m/%d") if self.actual_release_date?
  end

  private
  def release_resource
    if self.actual_release_date?
      self.resource.update_attributes(release_date: self.actual_release_date)
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
