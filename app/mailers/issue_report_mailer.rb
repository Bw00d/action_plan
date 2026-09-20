class IssueReportMailer < ApplicationMailer
  REPORT_TO = ENV.fetch('ISSUE_REPORT_TO', 'bwoodreid@gmail.com').freeze

  def new_report(report)
    @report = report
    @user   = report.user
    @page   = report.page_url

    mail(
      to:       REPORT_TO,
      reply_to: @user&.email,
      subject:  "[Action Plan] #{@report.kind_label}: #{@report.title.truncate(80)}"
    )
  end
end
