module Admin
  # Site admins review Request Access submissions here.
  class AccessRequestsController < ApplicationController
    include SkipAuthorization # gated on require_admin instead of Pundit
    before_action :require_admin
    before_action :set_access_request, only: %i[approve decline]

    # GET /admin/access_requests
    def index
      @pending  = AccessRequest.pending.recent_first
      @reviewed = AccessRequest.where.not(status: :pending).includes(:reviewed_by)
                               .order(reviewed_at: :desc).limit(50)
    end

    # POST /admin/access_requests/:id/approve
    def approve
      _user, raw_token = @access_request.approve!(current_user)
      AccessRequestMailer.approved(@access_request, raw_token).deliver_later
      redirect_to admin_access_requests_path,
                  notice: "Approved #{@access_request.full_name}. They've been emailed a link to sign in."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_access_requests_path,
                  alert: "Couldn't approve #{@access_request.email}: #{e.record.errors.full_messages.to_sentence}"
    end

    # POST /admin/access_requests/:id/decline
    def decline
      @access_request.decline!(current_user)
      redirect_to admin_access_requests_path, notice: "Declined #{@access_request.full_name}."
    end

    private

    def require_admin
      head :forbidden unless current_user&.admin?
    end

    def set_access_request
      @access_request = AccessRequest.pending.find(params[:id])
    end
  end
end
