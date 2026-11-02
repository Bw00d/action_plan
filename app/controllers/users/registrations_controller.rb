class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_account_update_params, only: [:update]

  # Open sign-up is closed; accounts come from incident invitations or
  # approved access requests. Profile editing (edit/update) stays.
  def new
    redirect_to new_access_request_path
  end

  def create
    redirect_to new_access_request_path
  end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: custom_parameters)
  end

  private

  def custom_parameters
    # Do NOT include attributes that the user is not supposed to change, such
    # as his own role. time_zone is safe — it only affects the user's own
    # display of dates/times, not other users.
    %i[first_name last_name time_zone]
  end
end
