class MedicalZone < ApplicationRecord
  belongs_to :medical_plan

  # Section 6 (division/branch/group) and Section 7 (remote camps)
  # share the same block of fields on the printed form, so one table
  # with a `kind` enum covers both. _prefix lets us call .division? /
  # .camp? without name clashes.
  enum kind: { division: 0, camp: 1 }, _prefix: :kind

  # Convenience that mirrors the enum prefix for scope-free use in the
  # view (`zone.division?`) without touching the predicate name.
  def division?; kind_division?; end
  def camp?;     kind_camp?;     end
end
