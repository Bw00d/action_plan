# Signed-in users find a qualified, available person and contact them.
# Profiles are edited at ProfilesController.
class DirectoryController < ApplicationController
  PER_PAGE = 25

  # GET /directory
  def index
    @on_assignment_ids = User.on_assignment_ids.to_set
    @users = policy_scope(User, policy_scope_class: ProfilePolicy::Scope)
             .directory_search(params[:q])
             .with_qualification(params[:qual])
             .with_directory_status(params[:status], @on_assignment_ids.to_a)
             .includes(qualifications: :position)
             .order(:last_name, :first_name)
             .page(params[:page]).per(PER_PAGE)
    @position_codes = Position.joins(:qualifications).distinct.order(:code).pluck(:code)
  end

  # GET /directory/:id
  def show
    @user = User.in_directory.friendly.find(params[:id])
    authorize @user, :show?, policy_class: ProfilePolicy

    # Only shared contact methods ever leave the server.
    @shared_phones = @user.contact_methods.shared.phone.to_a
    @shared_emails = @user.contact_methods.shared.email.to_a
    @qualifications = @user.qualifications.includes(:position).display_order
    @recent_assignments = @user.recent_assignments
    @current_assignment = @user.current_assignment
    # Loaded for admins only, so the view has nothing to leak otherwise.
    @emergency_contact = emergency_contact_for(@user) if policy_for(@user).view_emergency_contact?
  end

  private

  def policy_for(user)
    ProfilePolicy.new(current_user, user)
  end
  helper_method :policy_for

  def emergency_contact_for(user)
    { name: user.emergency_contact_name, phone: user.emergency_contact_phone,
      relation: user.emergency_contact_relation }
  end
end
