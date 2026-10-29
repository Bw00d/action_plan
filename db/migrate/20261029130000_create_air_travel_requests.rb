# Commercial air travel request sent to dispatch for a resource leaving
# (or being reassigned from) the incident. Identity fields are copied
# from the resource at creation so the printed form stays stable even
# if the resource record is edited or deleted later.
class CreateAirTravelRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :air_travel_requests do |t|
      t.references :incident, null: false, foreign_key: true
      t.references :resource, foreign_key: true

      t.string  :travel_type, null: false, default: 'DEMOB'
      t.string  :request_number
      t.string  :resource_name
      t.string  :unit_id
      t.string  :release_city
      t.string  :release_state

      t.date    :available_date
      t.string  :available_time
      t.integer :travel_hours
      t.integer :travel_minutes
      t.string  :depart_from
      t.string  :return_to

      # Travel questions — nil means "not answered".
      t.boolean :ground_support_needed
      t.boolean :drive_home_from_jetport
      t.boolean :rental_car_to_return
      t.boolean :picture_id
      t.boolean :hotel_needed
      t.boolean :agency_credit_card

      t.text    :special_instructions
      t.date    :last_date_available
      t.string  :reassignment_quals

      t.timestamps
    end
  end
end
