# Qualifications are taken as the user reports them; nobody certifies
# them, so the certified/self-reported tracking goes away.
class RemoveSourceFromQualifications < ActiveRecord::Migration[6.0]
  def change
    remove_reference :qualifications, :certified_by,
                     foreign_key: { to_table: :users, on_delete: :nullify }, index: true
    remove_column :qualifications, :certified_at, :datetime
    remove_column :qualifications, :source, :integer, null: false, default: 0
  end
end
