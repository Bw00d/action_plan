class OrgUnit < ApplicationRecord
  belongs_to :incident
  belongs_to :parent, class_name: 'OrgUnit', optional: true
  has_many :children, -> { order(:position) },
           class_name: 'OrgUnit', foreign_key: :parent_id, dependent: :destroy
  has_many :org_unit_assignments, -> { order(:position) }, dependent: :destroy
  has_many :resources, through: :org_unit_assignments
  has_many :assignments, dependent: :nullify
  has_many :plan_assignment_snapshots, dependent: :nullify
  has_many :ops_215_lines, dependent: :destroy

  enum kind: {
    command: 0,
    section: 1,
    branch: 2,
    division: 3,
    group: 4,
    non_209: 5
  }, _prefix: :kind

  acts_as_list scope: :parent_id, top_of_list: 1, add_new_at: :bottom

  validates :name, presence: true
  validates :kind, presence: true
  validate :parent_kind_must_be_valid

  scope :roots, -> { where(parent_id: nil) }

  ALLOWED_PARENT_KINDS = {
    'command'  => [nil],
    'section'  => [nil],
    'branch'   => ['section', 'command'],
    'division' => ['section', 'branch'],
    'group'    => ['section', 'branch'],
    # Flat bucket at the root of the board — no children allowed. Resources
    # assigned here are excluded from the Resource Tally, Glide Path, and
    # ICS-211 by the Incident#tally_resources scope.
    'non_209'  => [nil]
  }.freeze

  def self.allowed_child_kinds_for(parent_kind)
    ALLOWED_PARENT_KINDS.select { |_, parents| parents.include?(parent_kind) }.keys
  end

  def can_have_children?
    self.class.allowed_child_kinds_for(kind).any?
  end

  private

  def parent_kind_must_be_valid
    return if kind.nil?

    allowed = ALLOWED_PARENT_KINDS[kind]
    actual = parent&.kind

    return if allowed.include?(actual)

    errors.add(:parent, "of kind #{actual.inspect} is not allowed for a #{kind}")
  end
end
