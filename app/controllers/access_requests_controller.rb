# Public Request Access form, which replaces open sign-up. Site admins
# review submissions at Admin::AccessRequestsController.
class AccessRequestsController < ApplicationController
  include SkipAuthorization
  skip_before_action :authenticate_user!

  # Bots fill in every field; people never see this one.
  HONEYPOT_FIELD = :website

  # GET /access_requests/new
  def new
    @access_request = AccessRequest.new
  end

  # POST /access_requests
  def create
    # Pretend a bot's submission worked so it has no reason to retry.
    return redirect_to(new_user_session_path, notice: submitted_notice) if params[HONEYPOT_FIELD].present?

    @access_request = AccessRequest.new(access_request_params)
    if @access_request.save
      AccessRequestMailer.new_request(@access_request).deliver_later
      redirect_to new_user_session_path, notice: submitted_notice
    else
      render :new
    end
  end

  private

  def access_request_params
    params.require(:access_request).permit(:first_name, :last_name, :email, :position)
  end

  def submitted_notice
    "Thanks! Your request has been sent. You'll get an email once an administrator approves it."
  end
end
