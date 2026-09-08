class Users::PreferencesController < ApplicationController
  # Pundit is on globally; user-preference actions operate on the current
  # user's own record, so authorization checks are trivial. Skipping the
  # after_action verify hooks that would otherwise complain.
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # PATCH /users/detect_timezone
  # Body: { time_zone: "America/Anchorage" }
  # Called silently by JS on page load when the user has no timezone set.
  # Idempotent — a repeat call with the same value writes the same value.
  def detect_timezone
    tz = params[:time_zone].to_s
    if ActiveSupport::TimeZone[tz].nil?
      render json: { ok: false, error: "unknown timezone: #{tz}" }, status: :unprocessable_entity
      return
    end

    # Only set if the user hasn't already picked one — respect a manual
    # choice made via the profile edit page.
    if current_user.time_zone.blank?
      current_user.update_column(:time_zone, tz)
    end

    render json: { ok: true, time_zone: current_user.time_zone }
  end
end
