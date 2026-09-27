class FeatureRequestsController < ApplicationController
  include SkipAuthorization

  before_action :set_feature, only: %i[show upvote add_comment]

  # GET /feature_requests
  def index
    @features = IssueReport.feature_requests.ranked_by_upvotes.limit(200)
    # Preload comment counts so the index doesn't N+1.
    ids = @features.map(&:id)
    @comment_counts = IssueReportComment.where(issue_report_id: ids)
                                        .group(:issue_report_id).count
  end

  # GET /feature_requests/:id
  def show
    @comments = @feature.comments.chronological.includes(:user)
    @new_comment = IssueReportComment.new
  end

  # POST /feature_requests/:id/upvote
  def upvote
    return redirect_to feature_requests_path, alert: "Sign in to upvote." unless current_user

    existing = @feature.upvotes.find_by(user_id: current_user.id)
    if existing
      existing.destroy
    else
      @feature.upvotes.create(user: current_user)
    end
    redirect_back fallback_location: feature_requests_path
  end

  # POST /feature_requests/:id/comments
  def add_comment
    return redirect_to feature_request_path(@feature), alert: "Sign in to comment." unless current_user

    comment = @feature.comments.build(comment_params.merge(user: current_user))
    if comment.save
      redirect_to feature_request_path(@feature, anchor: "comment-#{comment.id}"),
                  notice: "Comment posted."
    else
      redirect_to feature_request_path(@feature),
                  alert: comment.errors.full_messages.to_sentence
    end
  end

  private

  def set_feature
    @feature = IssueReport.feature_requests.find(params[:id])
  end

  def comment_params
    params.require(:issue_report_comment).permit(:body)
  end
end
