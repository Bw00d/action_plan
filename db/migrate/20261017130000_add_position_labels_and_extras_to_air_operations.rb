class AddPositionLabelsAndExtrasToAirOperations < ActiveRecord::Migration[6.0]
  # Section 14 — add editable labels to the five standard position
  # rows (AOBD/ASGS/HEBM/HLCO/UAO) and introduce three extra blank
  # slots so the right side of the combined 13+14 table has one row
  # per freq row. Each extra slot carries its own label/name/phone.
  STANDARD = {
    'aobd' => 'AOBD',
    'asgs' => 'ASGS',
    'hebm' => 'HEBM',
    'hlco' => 'HLCO',
    'uao'  => 'UAO'
  }.freeze

  EXTRAS = %w[extra1 extra2 extra3].freeze

  def up
    STANDARD.each_key do |k|
      add_column :air_operations, "pos_#{k}_label", :string
    end
    EXTRAS.each do |k|
      add_column :air_operations, "pos_#{k}_label", :string
      add_column :air_operations, "pos_#{k}_name",  :string
      add_column :air_operations, "pos_#{k}_phone", :string
    end

    AirOperation.reset_column_information
    AirOperation.find_each do |ao|
      updates = STANDARD.transform_keys { |k| "pos_#{k}_label" }
      ao.update_columns(updates)
    end
  end

  def down
    EXTRAS.each do |k|
      remove_column :air_operations, "pos_#{k}_phone"
      remove_column :air_operations, "pos_#{k}_name"
      remove_column :air_operations, "pos_#{k}_label"
    end
    STANDARD.each_key do |k|
      remove_column :air_operations, "pos_#{k}_label"
    end
  end
end
