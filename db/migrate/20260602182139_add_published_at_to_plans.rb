class AddPublishedAtToPlans < ActiveRecord::Migration[6.0]
  def change
    add_column :plans, :published_at, :datetime
    add_index :plans, :published_at
  end
end
