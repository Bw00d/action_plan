class AirOpsUasEntry < ApplicationRecord
  self.table_name = 'air_ops_uas_entries'
  belongs_to :air_operation
end
