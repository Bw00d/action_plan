# ── Add these lines to your existing app/models/incident.rb ──
#
# (Shown as a standalone class for clarity; merge into your real model.)

class Incident < ApplicationRecord
  has_many :requests, dependent: :destroy

  # iroc_inc_id is the stable IROC identifier the importer matches on.
  # allow_nil so incidents created outside the IROC flow still validate.
  validates :iroc_inc_id, uniqueness: true, allow_nil: true

  # Convenience roll-ups built from imported requests.
  has_many :personnel_requests, -> { personnel }, class_name: "Request"
end
