class IssueReportComment < ApplicationRecord
  belongs_to :issue_report
  belongs_to :user

  validates :body, presence: true, length: { maximum: 5000 }

  scope :chronological, -> { order(:created_at) }

  def author_name
    name = [user.first_name, user.last_name].reject(&:blank?).join(' ')
    name.presence || user.email
  end
end
