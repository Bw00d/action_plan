# Entries on the ICS "215A" phone list — one row per contact, grouped
# by section on the incident's phone list page. Scoped to the incident
# (one list per incident, stable across operational periods — unlike
# the per-plan ICS forms).
class Phone215aEntry < ApplicationRecord
  # Rails' default tableize collapses "Phone215aEntry" → "phone215a_entries"
  # (no underscore before digits), which doesn't match the migration's
  # readable "phone_215a_entries". Pin it explicitly so both the file
  # names and the SQL stay human-friendly.
  self.table_name = 'phone_215a_entries'

  belongs_to :incident

  # Section labels on the phone list page. Order here drives the
  # display order of the section cards on the index view. "Agency" and
  # "Dispatch" are kept at the end — they're outside the normal ICS
  # command structure.
  SECTIONS = %w[Command Operations Plans Finance Logistics Medical Agency Dispatch].freeze

  # Minimum required to be useful on the printed list — a name and the
  # section it belongs under. Position + phone can be filled in later
  # as operators learn them, so no presence validation on those.
  validates :name,    presence: true
  validates :section, presence: true, inclusion: { in: SECTIONS }
end
