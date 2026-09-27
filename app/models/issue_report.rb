class IssueReport < ApplicationRecord
  KINDS = %w[bug question feature].freeze

  belongs_to :user,     optional: true
  belongs_to :incident, optional: true
  has_many   :comments, class_name: 'IssueReportComment', dependent: :destroy
  has_many   :upvotes,  class_name: 'IssueReportUpvote',  dependent: :destroy
  has_many   :upvoters, through: :upvotes, source: :user

  validates :kind, inclusion: { in: KINDS }
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, presence: true

  scope :feature_requests, -> { where(kind: 'feature') }
  # Feature requests page sort: upvotes first (most-wanted at top), then
  # newest. Uses a subquery count so ordering works across the full list.
  scope :ranked_by_upvotes, lambda {
    select("issue_reports.*, (SELECT COUNT(*) FROM issue_report_upvotes u WHERE u.issue_report_id = issue_reports.id) AS upvote_count")
      .order('upvote_count DESC, issue_reports.created_at DESC')
  }

  def kind_label
    case kind
    when 'bug'      then 'Bug Report'
    when 'question' then 'Question'
    when 'feature'  then 'Feature Request'
    else kind.to_s.titleize
    end
  end

  def author_name
    return 'Anonymous' unless user
    name = [user.first_name, user.last_name].reject(&:blank?).join(' ')
    name.presence || user.email
  end

  def upvoted_by?(some_user)
    return false unless some_user
    upvotes.exists?(user_id: some_user.id)
  end
end
