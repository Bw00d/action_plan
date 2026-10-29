# Commercial Air Travel Request — a printable form the Plans Section
# sends to dispatch so a resource can be booked on a flight home (or
# to a reassignment). Modeled on the eISuite form of the same name.
class AirTravelRequest < ApplicationRecord
  belongs_to :incident
  belongs_to :resource, optional: true

  TRAVEL_TYPES = %w[DEMOB REASSIGNMENT].freeze

  # [attribute, question] in printed order.
  TRAVEL_QUESTIONS = [
    [:ground_support_needed,   'Is ground support transportation needed?'],
    [:drive_home_from_jetport, 'Will this person drive themselves home from jetport?'],
    [:rental_car_to_return,    'Does this person have a rental car to return?'],
    [:picture_id,              'Does this person have a picture ID?'],
    [:hotel_needed,            'Does this person need hotel reservations at Demob?'],
    [:agency_credit_card,      'Does this person have an agency credit card?']
  ].freeze

  validates :travel_type, inclusion: { in: TRAVEL_TYPES }
  validates :resource_name, presence: true

  # Builds an unsaved request pre-filled from what we already know
  # about the resource: identity, home city/state, and the release
  # date/time off its demob if one has been started.
  def self.prefilled_for(incident, resource)
    req = incident.air_travel_requests.new
    return req unless resource

    req.resource       = resource
    req.request_number = resource.full_order_number
    req.resource_name  = resource.name
    req.unit_id        = resource.agency
    req.release_city   = resource.return_city
    req.release_state  = resource.return_state
    if (demob = resource.demob)
      req.available_date = demob.actual_release_date
      req.available_time = demob.actual_release_time
    end
    req
  end

  def release_to
    [release_city, release_state].reject(&:blank?).join(', ')
  end

  def answer_for(attr)
    case self[attr]
    when true  then 'YES'
    when false then 'NO'
    end
  end
end
