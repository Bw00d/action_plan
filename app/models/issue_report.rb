class IssueReport < ApplicationRecord
  KINDS = %w[bug question feature].freeze

  belongs_to :user,     optional: true
  belongs_to :incident, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, presence: true

  def kind_label
    case kind
    when 'bug'      then 'Bug Report'
    when 'question' then 'Question'
    when 'feature'  then 'Feature Request'
    else kind.to_s.titleize
    end
  end
end
