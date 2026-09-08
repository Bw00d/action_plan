# :nodoc:
class ApplicationController < ActionController::Base
  # Authorization gem
  include Pundit::Authorization

  protect_from_forgery with: :exception

  # Ensure that Pundit's #verify_policy_scoped or #verify_authorized are
  # called in all actions of all controllers. In other words, ensure
  # authorization policies are enforced everywhere.
  after_action :verify_authorized,
               except: :index,
               unless: :devise_controller?
  after_action :verify_policy_scoped,
               only: :index,
               unless: :devise_controller?

  # Require authentication for all requests. Add
  # skip_before_action :authenticate_user! to controllers that should not
  # require authentication.
  before_action :authenticate_user!, unless: :devise_controller?

  # Wrap every request in the current user's timezone so Time.zone.today
  # and Time.zone.now reflect their local day/time. Falls back to the
  # global config.time_zone when no user is signed in or the user hasn't
  # picked/detected one yet.
  around_action :with_user_timezone

  # Display user-friendly errors for the following exceptions
  rescue_from Pundit::NotAuthorizedError,
              with: :show_user_not_authorized_error
  rescue_from ActiveRecord::DeleteRestrictionError,
              with: :show_delete_restriction_error

  layout :set_layout

  private

  # Choose from 3 types of layouts: guest (not logged-in), user or admin
  def set_layout
    return 'guest' unless user_signed_in?
    current_user.admin? ? 'admin' : 'user'
  end

  # Rescue Pundit::NotAuthorizedError, which happens when a user tries to
  # access a resource for which he does not have permission.
  def show_user_not_authorized_error
    redirect_to request.referer || root_path,
                flash: { error: t(:not_authorized, scope: 'authorization') }
  end

  # Rescue raise ActiveRecord::DeleteRestrictionError, which happens when trying
  # do delete records restricted by "dependent: :restrict_with_exception"
  def show_delete_restriction_error(exception)
    redirect_to request.referer || root_path,
                flash: { error: exception.message }
  end

  # Set Time.zone for the duration of the request. Time.use_zone reverts
  # cleanly at the end via a block, so background jobs or later requests
  # aren't polluted. Safe to call with a bad value — invalid strings just
  # fall through to the yield without an assignment.
  def with_user_timezone
    tz = current_user&.time_zone
    if tz.present? && ActiveSupport::TimeZone[tz]
      Time.use_zone(tz) { yield }
    else
      yield
    end
  end
end
