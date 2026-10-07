# Activity-feed entry for a Resource. Three kinds share the table:
#
#   comment         — plain-text note (body)
#   scheduled_swap  — upcoming crew swap, carries leader/fwd/lwd/phone
#                     for the INCOMING operator. Shows a SWAP NOW button
#                     on the T-card modal. Editable/deletable until the
#                     user clicks SWAP NOW.
#   completed_swap  — immutable record of a past operator (leader + the
#                     fwd/lwd dates they covered). Automatically created
#                     by ResourceEventsController#swap_now when a
#                     scheduled_swap is executed, capturing the OUTGOING
#                     operator's values from the Resource.
class ResourceEvent < ApplicationRecord
  belongs_to :resource
  belongs_to :user, optional: true

  enum kind: {
    comment:        0,
    scheduled_swap: 1,
    completed_swap: 2
  }

  validates :kind, presence: true

  # Comment events need a body; SCHEDULED swap events need at least a
  # leader (the user is entering a future operator — blank is almost
  # certainly a mistake). COMPLETED swap events have no such minimum —
  # they're historical snapshots of whatever was on the Resource at
  # swap time, including resources that had no leader logged yet.
  validate :body_or_swap_fields_present

  # Feed ordering: scheduled swaps float to the top, sorted by their
  # swap FWD (earliest = next-up) so the user sees "the next thing I
  # need to action" at a glance. Everything else (comments, completed
  # swaps) falls below in newest-first chronological order.
  #
  # Done as a two-key SQL ORDER:
  #   1. kind=scheduled_swap first (0), everything else (1)
  #   2. scheduled: fwd ASC (NULLs last — treat as "future-dated unknown")
  #      others:    created_at DESC
  #
  # `.reorder` instead of `.order` — the Resource has_many sets a
  # default ASC order and `.order` APPENDS, so the DESC would get
  # ignored. `.reorder` blows the default away.
  scope :newest_first, -> {
    reorder(
      Arel.sql("CASE WHEN kind = #{kinds[:scheduled_swap]} THEN 0 ELSE 1 END ASC"),
      Arel.sql('CASE WHEN kind = 1 THEN fwd END ASC NULLS LAST'),
      created_at: :desc
    )
  }

  def swap?
    scheduled_swap? || completed_swap?
  end

  # Editable only while scheduled; comments stay editable too. Completed
  # swaps are historical — immutable.
  def editable?
    comment? || scheduled_swap?
  end

  private

  def body_or_swap_fields_present
    if comment?
      errors.add(:body, "can't be blank") if body.blank?
    elsif scheduled_swap?
      errors.add(:leader, "can't be blank") if leader.blank?
    end
    # completed_swap: no required fields — purely historical.
  end
end
