# One-time cleanup: dates typed as "10/29/26" were saved as year 0026
# before Resource bumped years below 100 into the 2000s. Moves those
# rows forward 2000 years. Not reversible (the typo isn't worth keeping).
class FixTwoDigitResourceYears < ActiveRecord::Migration[6.0]
  COLUMNS = %w[fwd checkin_date mobilization_date].freeze

  def up
    COLUMNS.each do |col|
      execute <<~SQL
        UPDATE resources
        SET #{col} = (#{col} + INTERVAL '2000 years')::date
        WHERE #{col} < DATE '0100-01-01'
      SQL
    end
  end

  def down; end
end
