class Roster < ApplicationRecord
  belongs_to :resource
  belongs_to :request, optional: true

  default_scope { order(:position_num, :order_number) }
end
