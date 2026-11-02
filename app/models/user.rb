# User model used for authentication by Devise
class User < ApplicationRecord
  # Use slugs instead of DB IDs in URLs
  include FriendlyId
  friendly_id :full_name, use: :slugged
  has_many :plans, dependent: :destroy
  has_many :incidents, dependent: :destroy
  has_and_belongs_to_many :incidents

  # Directory profile. assigned_resources are the incident Resources this
  # person filled (linked by email at check-in; see Resource#link_user).
  has_many :contact_methods, -> { ordered }, dependent: :destroy
  has_many :qualifications, dependent: :destroy
  has_many :positions, through: :qualifications
  has_many :assigned_resources, class_name: 'Resource', dependent: :nullify

  # Roles used by the authorization setup
  enum role: { user: 0, admin: 1 }
  # Self-set availability. "On assignment" isn't stored: it's derived from
  # a current assigned resource (see #directory_status).
  enum availability: { available: 0, unavailable: 1 }, _prefix: :marked

  # **We should NOT validate e-mail uniqueness, e-mail regex or password
  # confirmation here**. Devise's Validatable module is enabled so it already
  # validates those attributes (in the registerable form and the user management
  # form in the admin namespace). Validating again here will produce duplicated
  # error messages.

  validates :first_name, :last_name, presence: true
  validates :home_unit, :dispatch_center, length: { maximum: 20 }
  before_validation :normalize_directory_codes
  # Custom password strength validation
  validate :password_strength

  # Callback to set the default role of new records
  after_initialize :set_default_role, if: :new_record?

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :timeoutable, :trackable, :validatable,
         :confirmable, :lockable

  # Allow a single Ransack search field to search the virtual attr 'full_name'
  # If first_name is 'John' and last_name is 'Doe', this will enable us to
  # search for 'John', 'Doe' or 'John Doe' using the 'cont' predicate.
  # See https://github.com/activerecord-hackery/ransack/wiki/using-ransackers
  ransacker :full_name do |parent|
    Arel::Nodes::InfixOperation.new(
      '||',
      Arel::Nodes::InfixOperation.new(
        '||',
        parent.table[:first_name],
        Arel::Nodes.build_quoted(' ')
      ),
      parent.table[:last_name]
    )
  end

  def full_name
    [first_name, last_name].join(' ')
  end

  def initials
    [first_name, last_name].map { |n| n.to_s.strip[0] }.join.upcase
  end

  # ── Directory ────────────────────────────────────────────────────────
  # Confirmed accounts only, so invite placeholders and unconfirmed
  # sign-ups never appear.
  scope :in_directory, -> { where.not(confirmed_at: nil) }

  # Matches name, qualification code, home unit or dispatch center.
  def self.directory_search(query)
    q = query.to_s.strip
    return all if q.empty?

    like = "%#{sanitize_sql_like(q)}%"
    qual_user_ids = Qualification.joins(:position).where('positions.code ILIKE ?', like).select(:user_id)
    where("(users.first_name || ' ' || users.last_name) ILIKE :like OR users.home_unit ILIKE :like " \
          'OR users.dispatch_center ILIKE :like', like: like)
      .or(where(id: qual_user_ids))
  end

  def self.with_qualification(code)
    return all if code.blank?
    where(id: Qualification.joins(:position).where(positions: { code: code.to_s.upcase }).select(:user_id))
  end

  # :available, :on_assignment or :unavailable. Uses SQL-friendly id sets so
  # the directory can filter and still paginate in the database.
  def self.with_directory_status(status, on_ids = on_assignment_ids)
    case status.to_s
    when 'on_assignment' then where(id: on_ids)
    when 'available'     then marked_available.where.not(id: on_ids)
    when 'unavailable'   then marked_unavailable.where.not(id: on_ids)
    else all
    end
  end

  # Users with a current assignment. Decided in Ruby because a resource's
  # last work day comes from its shift timeline, not a column.
  def self.on_assignment_ids
    Resource.where.not(user_id: nil).where(release_date: nil, spacer: false)
            .includes(:resource_events).select(&:current_assignment?).map(&:user_id).uniq
  end

  def current_assignment
    return @current_assignment if defined?(@current_assignment)
    @current_assignment = assigned_resources.where(release_date: nil, spacer: false)
                                            .includes(:incident, :resource_events)
                                            .select(&:current_assignment?)
                                            .max_by { |r| r.fwd || r.created_at.to_date }
  end

  # Pass on_assignment_ids when listing many users to skip the per-user
  # assignment lookup.
  def directory_status(on_ids = nil)
    on = on_ids ? on_ids.include?(id) : current_assignment.present?
    return :on_assignment if on
    marked_unavailable? ? :unavailable : :available
  end

  # The user's own date wins; otherwise the day after the current
  # assignment's last work day.
  def available_after
    return available_on if available_on
    lwd = current_assignment&.last_work_day
    lwd.is_a?(Date) ? lwd + 1 : nil
  end

  def recent_assignments(limit = 5)
    assigned_resources.where(spacer: false).includes(:incident)
                      .order(Arel.sql('resources.fwd DESC NULLS LAST'), created_at: :desc).limit(limit)
  end

  # Up to `limit` quals for directory badges, best first. Sorts in Ruby so
  # the directory can preload qualifications: :position for every row.
  def badge_qualifications(limit = 3)
    qualifications.sort_by { |q| [q.trainee? ? 1 : 0, q.position.code] }.first(limit)
  end

  # Creates a placeholder account for someone who'll finish setting it up
  # from an emailed link (incident invites and approved access requests).
  # A random password satisfies :validatable, and the raw invitation token
  # piggybacks on Devise's confirmation_token. Returns [user, raw_token];
  # check user.persisted? for success.
  def self.create_invited(email:, first_name: 'Pending', last_name: 'Invitee')
    raw_token, digest = Devise.token_generator.generate(User, :confirmation_token)
    password = SecureRandom.hex(16) + 'Aa1' # meets password_strength rules
    user = new(email: email, first_name: first_name, last_name: last_name,
               password: password, password_confirmation: password)
    user.skip_confirmation_notification!
    user.confirmation_token   = digest
    user.confirmation_sent_at = Time.current
    user.save
    [user, raw_token]
  end

  # Issues a fresh invitation token for an existing, unconfirmed account so
  # its owner can set the password through the invitation link. Returns the
  # raw token.
  def regenerate_invitation_token!
    raw_token, digest = Devise.token_generator.generate(User, :confirmation_token)
    update_columns(confirmation_token: digest, confirmation_sent_at: Time.current)
    raw_token
  end

  private

  def normalize_directory_codes
    self.home_unit       = home_unit.to_s.strip.upcase.presence
    self.dispatch_center = dispatch_center.to_s.strip.upcase.presence
    self.emergency_contact_phone = PhoneNumber.format(emergency_contact_phone).presence
  end

  def set_default_role
    # self.my_enum ||= :default_value does not work as it does not apply
    # the default value if the controller passes "nil" as a value for the enum.
    self.role = :user if role.blank?
  end

  # TODO: extract this to a validator class
  def password_strength
    minimum_length = 8
    # Regex matches at least one lower case letter, one uppercase and one digit
    complexity_regex = /\A(?=.*[a-z])(?=.*[A-Z])(?=.*[0-9])/
    # When a user is updated but not its password, the password param is nil
    if password.present? &&
       (password.length < minimum_length || !password.match(complexity_regex))
      errors.add :password, :weak_password
    end
  end
end
