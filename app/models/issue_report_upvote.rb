class IssueReportUpvote < ApplicationRecord
  belongs_to :issue_report
  belongs_to :user

  validates :user_id, uniqueness: { scope: :issue_report_id }
end
