# Directory profiles (DirectoryController, ProfilesController). The record
# is a User. UserPolicy is separate: it guards admin user management.
class ProfilePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      user.present? ? scope.in_directory : scope.none
    end
  end

  def index?
    user.present?
  end

  def show?
    user.present?
  end

  # Your own status, availability, contact sharing and self-reported quals.
  def update?
    user.present? && user == record
  end

  # Emergency contacts are admin-only on profiles, including your own.
  def view_emergency_contact?
    user.present? && user.admin?
  end

  def manage_qualifications?
    user.present? && user.admin?
  end
end
