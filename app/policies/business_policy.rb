# frozen_string_literal: true

class BusinessPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    user.present? && (user.provider? || user.admin?)
  end

  def update?
    user.present? && (owner? || admin?)
  end

  def destroy?
    user.present? && (owner? || admin?)
  end

  def manage_services?
    user.present? && (owner? || admin?)
  end

  def view_bookings?
    user.present? && (owner? || admin?)
  end

  def manage_staff?
    return false if current_user.blank?
    return true if owner?
    return true if admin?

    current_user.role_at(record) == "manager"
  end

  def add_photos?
    user.present? && (owner? || admin?)
  end

  def remove_photo?
    user.present? && (owner? || admin?)
  end

  def owner?
    record.user_id == current_user&.id
  end

  def admin?
    current_user&.admin?
  end

  def impersonator_admin?
    impersonator&.admin?
  end

  private

  def current_user
    user.is_a?(Hash) ? user[:user] : user
  end

  def impersonator
    user.is_a?(Hash) ? user[:impersonator] : nil
  end

  class Scope < Scope
    def resolve
      actual_user = user.is_a?(Hash) ? user[:user] : user
      if actual_user&.admin?
        scope.all
      elsif actual_user&.provider?
        scope.kept.where(user_id: actual_user.id)
      else
        scope.kept
      end
    end
  end
end
