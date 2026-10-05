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

  # Comment events need a body; swap events need at least a leader to
  # be worth logging. LWD stays optional at the model level (the
  # scheduled form requires it client-side) so legacy data can import
  # cleanly.
  validate :body_or_swap_fields_present

  # `.reorder` instead of `.order` — the Resource has_many sets a
  # default ASC order, and .order APPENDS clauses (so the final SQL
  # would be "ORDER BY created_at ASC, created_at DESC" and the DESC
  # would be ignored). .reorder blows the ASC away cleanly.
  scope :newest_first, -> { reorder(created_at: :desc) }

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
    elsif swap?
      errors.add(:leader, "can't be blank") if leader.blank?
    end
  end
end
