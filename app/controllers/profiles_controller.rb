# The signed-in user's own directory profile: status, availability, home
# unit and dispatch center, emergency contact, which contacts are shared,
# and qualifications.
class ProfilesController < ApplicationController
  before_action :set_user

  # GET /profile/edit
  def edit
    load_edit_collections
  end

  # PATCH /profile
  def update
    if @user.update(profile_params)
      redirect_to edit_profile_path, notice: 'Profile updated.'
    else
      load_edit_collections
      render :edit
    end
  end

  private

  def set_user
    @user = current_user
    authorize @user, :update?, policy_class: ProfilePolicy
  end

  def load_edit_collections
    @contact_methods = @user.contact_methods.to_a
    @qualifications  = @user.qualifications.includes(:position).display_order
    @positions       = Position.alphabetical.where.not(id: @user.qualifications.select(:position_id))
    @contact_method  ||= @user.contact_methods.build
    @qualification   ||= Qualification.new
  end

  def profile_params
    params.require(:user).permit(:home_unit, :dispatch_center, :availability, :available_on,
                                 :emergency_contact_name, :emergency_contact_phone,
                                 :emergency_contact_relation)
  end
end
