class AddFrequencyLabelsToAirOperations < ActiveRecord::Migration[6.0]
  # Section 13 row labels (A/A TFR, A/A Rotor, …) are now stored per
  # air_operations row so they can be edited inline (e.g. renamed to
  # match a local naming convention). Columns are nullable; the model's
  # before_create seeds defaults for new rows and this migration back-
  # fills existing ones with the standard ICS 220 WF labels.
  LABELS = {
    'aa_tfr'       => 'A/A (TFR)',
    'aa_rotor'     => 'A/A Rotor',
    'aa_briefing'  => 'A/A Briefing/Handoff',
    'ag_primary'   => 'A/G Primary',
    'ag_secondary' => 'A/G Secondary',
    'ag_tactical'  => 'A/G Tactical',
    'deck'         => 'DECK',
    'tolc'         => 'TOLC'
  }.freeze

  def up
    LABELS.each_key do |key|
      add_column :air_operations, "freq_#{key}_label", :string
    end

    AirOperation.reset_column_information
    AirOperation.find_each do |ao|
      updates = LABELS.transform_keys { |k| "freq_#{k}_label" }
      ao.update_columns(updates)
    end
  end

  def down
    LABELS.each_key do |key|
      remove_column :air_operations, "freq_#{key}_label"
    end
  end
end
