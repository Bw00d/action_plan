class CommoPlan < ApplicationRecord
  belongs_to :plan
  # Order by (created_at, id). id is a monotonic tiebreaker so rapidly-
  # added channels that share a timestamp still render in insertion order.
  has_many :commo_items, -> { order(:created_at, :id) }, dependent: :destroy
end
