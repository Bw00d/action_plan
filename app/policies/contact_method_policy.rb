# Only the owner manages their phone numbers and emails.
class ContactMethodPolicy < ApplicationPolicy
  %w[create? update? destroy?].each do |name|
    define_method(name) { user.present? && record.user_id == user.id }
  end
end
