class AirOperation < ApplicationRecord
  belongs_to :plan

  has_many :helicopters,  -> { order(:position, :id) },
                          class_name: 'AirOpsHelicopter',
                          dependent: :destroy
  has_many :supervisions, -> { order(:position, :id) },
                          class_name: 'AirOpsSupervision',
                          dependent: :destroy
  has_many :uas_entries,  -> { order(:position, :id) },
                          class_name: 'AirOpsUasEntry',
                          dependent: :destroy

  # Section 13 freq row labels and section 14 position row labels both
  # live as columns so they can be edited inline. New records get the
  # ICS 220 WF defaults seeded here; existing records were back-filled
  # by the AddFrequencyLabelsToAirOperations and
  # AddPositionLabelsAndExtrasToAirOperations migrations.
  before_create :seed_frequency_labels
  before_create :seed_position_labels

  # Row labels for the two fixed-grid sections. Column drives which DB
  # columns the view reads (freq_<key>_* / pos_<key>_*); label is the
  # printed name.
  FREQUENCY_ROWS = [
    { key: 'aa_tfr',       label: 'A/A (TFR)' },
    { key: 'aa_rotor',     label: 'A/A Rotor' },
    { key: 'aa_briefing',  label: 'A/A Briefing/Handoff' },
    { key: 'ag_primary',   label: 'A/G Primary' },
    { key: 'ag_secondary', label: 'A/G Secondary' },
    { key: 'ag_tactical',  label: 'A/G Tactical' },
    { key: 'deck',         label: 'DECK' },
    { key: 'tolc',         label: 'TOLC' }
  ].freeze

  # 8 slots to match section 13's 8 freq rows. The first five seed with
  # the ICS 220 WF defaults (AOBD / ASGS / HEBM / HLCO / UAO); the last
  # three start blank so the user can add their own positions inline.
  POSITION_ROWS = [
    { key: 'aobd',   label: 'AOBD'  },
    { key: 'asgs',   label: 'ASGS'  },
    { key: 'hebm',   label: 'HEBM'  },
    { key: 'hlco',   label: 'HLCO'  },
    { key: 'uao',    label: 'UAO'   },
    { key: 'extra1', label: ''      },
    { key: 'extra2', label: ''      },
    { key: 'extra3', label: ''      }
  ].freeze

  EXTRACTION_COLUMNS = [
    { key: 'medevac',   label: 'Medevac'                },
    { key: 'shorthaul', label: 'Shorthaul'              },
    { key: 'hoist',     label: 'Hoist'                  }
  ].freeze

  private

  def seed_frequency_labels
    FREQUENCY_ROWS.each do |row|
      col = "freq_#{row[:key]}_label"
      self[col] = row[:label] if self[col].blank?
    end
  end

  def seed_position_labels
    POSITION_ROWS.each do |row|
      next if row[:label].blank?           # extras intentionally start blank
      col = "pos_#{row[:key]}_label"
      self[col] = row[:label] if self[col].blank?
    end
  end
end
