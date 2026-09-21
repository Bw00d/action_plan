class AddPreparedAtToPlans < ActiveRecord::Migration[6.0]
  def up
    add_column :plans, :prepared_at, :datetime unless column_exists?(:plans, :prepared_at)

    # Backfill from the legacy date_prepare + time_prepared pair. Only
    # touches rows that don't already have prepared_at set.
    Plan.reset_column_information
    Plan.where(prepared_at: nil).find_each do |plan|
      date = plan.read_attribute(:date_prepare)
      next unless date
      time = plan.read_attribute(:time_prepared).to_s.strip
      hour, min = 0, 0
      if time =~ /\A(\d{1,2}):?(\d{2})\z/
        hour = Regexp.last_match(1).to_i
        min  = Regexp.last_match(2).to_i
      end
      plan.update_columns(prepared_at: Time.zone.local(date.year, date.month, date.day, hour, min))
    rescue ArgumentError
      next
    end
  end

  def down
    remove_column :plans, :prepared_at if column_exists?(:plans, :prepared_at)
  end
end
