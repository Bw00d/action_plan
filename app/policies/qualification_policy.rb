# Admins manage every qualification, including certifying them. Users may
# only add, change or remove their own self-reported ones; once a qual is
# certified it's admin-only.
class QualificationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      return scope.none unless user
      user.admin? ? scope.all : scope.where(user_id: user.id)
    end
  end

  def create?
    admin? || own_self_reported?
  end

  def update?
    admin? || own_self_reported?
  end

  def destroy?
    admin? || own_self_reported?
  end

  private

  def admin?
    user.present? && user.admin?
  end

  # Checks the stored source as well as any pending change, so a user
  # can't edit a certified qual or flip their own to certified.
  def own_self_reported?
    return false unless user.present? && record.user_id == user.id
    record.self_reported? && record.source_was.in?([nil, 'self_reported'])
  end
end
