class AddObjectivesTextToPlans < ActiveRecord::Migration[6.0]
  # Free-form text replacement for the old Objective records list on the
  # 202. Objective records themselves stay in the schema (has_many
  # :objectives) so existing data is untouched.
  def change
    add_column :plans, :objectives_text, :text
  end
end
