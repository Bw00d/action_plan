class DemobNotification < ApplicationRecord
  belongs_to :incident
  belongs_to :resource
  belongs_to :demob, optional: true

  scope :pending,      -> { where(transmitted: false) }
  scope :transmitted,  -> { where(transmitted: true) }

  # Builds (and saves) a notification pre-populated from a Demob + its
  # Resource + incident. Called by Demob's callback when actual_release_date
  # first appears. Idempotent — returns the existing notification if one
  # already exists for this demob.
  def self.from_demob(demob)
    return nil unless demob.resource
    return nil unless demob.actual_release_date

    existing = find_by(demob_id: demob.id)
    return existing if existing

    resource = demob.resource
    create!(
      incident:              resource.incident,
      resource:              resource,
      demob:                 demob,
      request_number:        resource.full_order_number,
      unit_id:               resource.agency,
      name:                  resource.name,
      actual_release_date:   demob.actual_release_date,
      actual_release_time:   demob.actual_release_time,
      return_travel_method:  demob.travel_method,
      demob_city_state:      demob.destination,
      ron:                   !!demob.ron,
      ron_location:          demob.new_location,
      est_arrival_date:      demob.edd,
      est_arrival_time:      demob.edt,
      remarks:               demob.remarks
    )
  end

  def mark_transmitted!
    update!(transmitted: true, transmitted_at: Time.current)
  end

  def ron_flag
    ron ? 'Y' : 'N'
  end
end
