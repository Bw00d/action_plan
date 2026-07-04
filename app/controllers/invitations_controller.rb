class InvitationsController < ApplicationController
  # Anyone with a valid token can complete their invitation, so we skip
  # Devise's auth. Existing users who happen to be signed in still land here
  # fine — the accept form just sets their password and clears the token.
  skip_before_action :authenticate_user!

  before_action :find_user_by_token, only: [:edit, :update]

  # GET /invitations/:invitation_token/accept
  def edit
    unless @user
      redirect_to new_user_session_path, alert: "That invitation link is invalid or has expired."
      return
    end
  end

  # PATCH /invitations/:invitation_token/accept
  def update
    unless @user
      redirect_to new_user_session_path, alert: "That invitation link is invalid or has expired."
      return
    end

    if @user.update(invitation_params)
      @user.confirm unless @user.confirmed?
      @user.update_columns(confirmation_token: nil)
      sign_in(@user)
      redirect_to incidents_path, notice: "Welcome, #{@user.first_name}! Your account is set up."
    else
      render :edit
    end
  end

  private

  def find_user_by_token
    raw = params[:invitation_token].to_s
    return @user = nil if raw.blank?
    digest = Devise.token_generator.digest(User, :confirmation_token, raw)
    @user = User.find_by(confirmation_token: digest)
  end

  def invitation_params
    params.require(:user).permit(:first_name, :last_name, :password, :password_confirmation)
  end
end
