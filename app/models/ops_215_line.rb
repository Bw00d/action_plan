class Ops215Line < ApplicationRecord
  # Rails' inflector turns Ops215Line into "ops215_lines" (no underscore
  # before the number); the migration uses "ops_215_lines". Pin it.
  self.table_name = 'ops_215_lines'

  belongs_to :incident
  belongs_to :org_unit

  validates :day,      presence: true
  validates :position, presence: true
  validates :req,      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :position, uniqueness: { scope: [:incident_id, :org_unit_id, :day] }
end
