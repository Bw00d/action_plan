class IssueReportsController < ApplicationController
  include SkipAuthorization

  def new
    @issue_report = IssueReport.new(kind: params[:kind].presence || 'bug')
    # XHR = the floating bug icon's modal — render just the form, no
    # Bootstrap container/col wrapper (those clip at fixed widths and
    # overflow the modal on md/lg viewports).
    render partial: 'form', layout: false if request.xhr?
  end

  def create
    @issue_report = IssueReport.new(issue_report_params)
    @issue_report.user_id     = current_user&.id
    @issue_report.incident_id = params[:issue_report][:incident_id].presence
    @issue_report.page_url    = params[:issue_report][:page_url].presence

    if @issue_report.save
      begin
        IssueReportMailer.new_report(@issue_report).deliver_later
      rescue => e
        Rails.logger.error("IssueReportMailer failed: #{e.class}: #{e.message}")
      end
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, notice: 'Thanks — your report was submitted.' }
        format.json { render json: { ok: true, id: @issue_report.id } }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { ok: false, errors: @issue_report.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def issue_report_params
    params.require(:issue_report).permit(:kind, :title, :description)
  end
end
