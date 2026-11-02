# Users add, change and remove their own qualifications. Admins may do the
# same for anyone.
class QualificationPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      return scope.none unless user
      user.admin? ? scope.all : scope.where(user_id: user.id)
    end
  end

  %w[create? update? destroy?].each do |name|
    define_method(name) { user.present? && (user.admin? || record.user_id == user.id) }
  end
end
