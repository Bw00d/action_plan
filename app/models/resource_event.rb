# Activity-feed entry for a Resource. Five kinds share the table:
#
#   comment         — plain-text note (body)
#
#   work            — one operator's shift on this resource. Carries
#                     leader/phone + fwd (planned start) + lwd (planned
#                     end) + actual_fwd/actual_lwd. Order chronologically
#                     by fwd ASC; gaps are legal and represent R&R or
#                     any other scheduled break. See SHIFT_REFACTOR_PLAN.md.
#   rnr             — a scheduled R&R break. leader/phone are inherited
#                     for display; fwd/lwd are the planned R&R interval.
#                     An :rnr entry explicitly excludes the resource
#                     from "present on day" during that interval.
#
#   scheduled_swap  — LEGACY. Will be rewritten to :work by the shift
#                     refactor backfill. Keep the enum value so partially
#                     migrated environments stay readable.
#   completed_swap  — LEGACY. Will be rewritten to :work by the shift
#                     refactor backfill.
class ResourceEvent < ApplicationRecord
  belongs_to :resource
  belongs_to :user, optional: true

  enum kind: {
    comment:        0,
    scheduled_swap: 1,
    completed_swap: 2,
    work:           3,
    rnr:            4
  }

  validates :kind, presence: true

  validate :body_or_swap_fields_present

  # Feed ordering: unpromoted shift entries (`:work` with no actual_fwd
  # yet — the "next thing to action") float to the top, sorted by
  # planned fwd ASC. Everything else falls below in created_at DESC.
  #
  # `.reorder` instead of `.order` — the Resource has_many sets a
  # default ASC order and `.order` APPENDS, so the DESC would get
  # ignored. `.reorder` blows the default away.
  scope :newest_first, -> {
    work_kind = kinds[:work]
    reorder(
      Arel.sql("CASE WHEN kind = #{work_kind} AND actual_fwd IS NULL THEN 0 ELSE 1 END ASC"),
      Arel.sql("CASE WHEN kind = #{work_kind} AND actual_fwd IS NULL THEN fwd END ASC NULLS LAST"),
      created_at: :desc
    )
  }

  # Shim: in the pre-shift-refactor model, swap-related UI gated on
  # `scheduled_swap?` (upcoming — editable, offers SWAP NOW) and
  # `completed_swap?` (immutable past). Post-refactor those are both
  # :work entries differentiated by actual_fwd. Override the enum-
  # generated predicates to also match the new shape so the activity
  # feed partial, the T-card header, and anything else that gates on
  # these names keep rendering correctly. The `||` legacy branch
  # covers the (now-impossible but safely-handled) case of a stray
  # legacy row.
  def scheduled_swap?
    kind == 'scheduled_swap' || (work? && actual_fwd.nil?)
  end

  # A :work entry represents a FINISHED past operator only when both
  # actual_fwd AND actual_lwd are set. actual_fwd without actual_lwd
  # is the CURRENT operator — rendered in the T-card header, not the
  # activity feed, so this predicate deliberately excludes it.
  def completed_swap?
    kind == 'completed_swap' || (work? && actual_fwd.present? && actual_lwd.present?)
  end

  # The resource's active operator. Lives in the T-card header, so
  # the activity feed partial filters these out to avoid duplicating
  # the header info.
  def current_work?
    work? && actual_fwd.present? && actual_lwd.nil?
  end

  def swap?
    scheduled_swap? || completed_swap?
  end

  # Editable while the entry hasn't been promoted yet (upcoming :work
  # and upcoming :rnr). Comments stay editable too. Promoted entries
  # (actual_fwd set) are historical and immutable.
  def editable?
    comment? ||
      (work? && actual_fwd.nil?) ||
      (rnr? && actual_fwd.nil?) ||
      kind == 'scheduled_swap'   # legacy safety
  end

  private

  def body_or_swap_fields_present
    case kind
    when 'comment'
      errors.add(:body, "can't be blank") if body.blank?
    when 'scheduled_swap', 'work'
      errors.add(:leader, "can't be blank") if leader.blank?
      errors.add(:fwd,    "can't be blank") if fwd.blank?
    when 'rnr'
      errors.add(:fwd, "can't be blank") if fwd.blank?
      errors.add(:lwd, "can't be blank") if lwd.blank?
    end
    # completed_swap: no required fields — purely historical.
  end
end
